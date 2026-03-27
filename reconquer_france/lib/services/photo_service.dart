import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'hex_grid_service.dart';
import 'sync_service.dart';
import '../models/trip_photo.dart';


class PhotoService {
  static const _uuid = Uuid();

  // SharedPreferences key for the last successful import timestamp.
  static const _kLastImportKey = 'photo_last_import_ms';

  // Held so the callback can be removed when auto-import is stopped.
  static ValueChanged<MethodCall>? _changeCallback;

  // ── Permission ────────────────────────────────────────────────────────────

  /// Request photo library access upfront and guide the user to grant it.
  ///
  /// On iOS 14+ when the user chose "Limited" access, presents the native
  /// photo-picker so they can expand the allowed set or switch to "All Photos"
  /// in Settings. Returns true if any level of access was granted.
  static Future<bool> requestPhotoPermission() async {
    final state = await PhotoManager.requestPermissionExtend();

    if (state == PermissionState.limited) {
      // "Limited" means the user selected specific photos. Show the native
      // limited-access management UI so they can choose "All Photos".
      await PhotoManager.presentLimited();
      // Re-check after the picker dismisses.
      final recheck = await PhotoManager.requestPermissionExtend();
      return recheck.isAuth;
    }

    if (!state.isAuth) {
      // Permanently denied — open Settings so the user can change it.
      await PhotoManager.openSetting();
    }

    return state.isAuth;
  }

  // ── Auto-import (background library listener) ─────────────────────────────

  /// Register a photo-library change listener so new photos taken on the
  /// device are automatically imported without any user action.
  /// Call once at app startup (main.dart). Safe to call multiple times.
  static Future<void> startAutoImport(String tripId) async {
    if (_changeCallback != null) return; // already running

    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;

    _changeCallback = (_) async {
      // Library changed — pull in anything new since last import.
      await importPhotosFromLibrary(tripId);
    };
    PhotoManager.addChangeCallback(_changeCallback!);
    PhotoManager.startChangeNotify();
  }

  /// Stop listening for library changes (call on app dispose / logout).
  static void stopAutoImport() {
    if (_changeCallback != null) {
      PhotoManager.removeChangeCallback(_changeCallback!);
      _changeCallback = null;
    }
    PhotoManager.stopChangeNotify();
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Import photos from the device library with EXIF GPS parsing.
  ///
  /// Incremental: only photos taken *after* the last successful import are
  /// processed, and photos already stored (matched by assetId) are skipped.
  /// This makes repeated calls fast and prevents duplicates.
  static Future<List<TripPhoto>> importPhotosFromLibrary(String tripId) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      PhotoManager.openSetting();
      return [];
    }

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kLastImportKey);
    final lastDate = lastMs != null
        ? DateTime.fromMillisecondsSinceEpoch(lastMs)
        : null;

    // Collect already-imported assetIds to skip duplicates.
    final existingIds = SyncService.getAllLocalPhotos()
        .map((p) => p['assetId'] as String? ?? '')
        .toSet();

    // onlyAll:true returns the virtual "All Photos" album on both platforms.
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) return [];

    final allPhotos =
        await albums.first.getAssetListRange(start: 0, end: 9999);

    // Only process assets we haven't seen before.
    final toProcess = allPhotos.where((asset) {
      if (existingIds.contains(asset.id)) return false;
      if (lastDate != null && !asset.createDateTime.isAfter(lastDate)) {
        return false;
      }
      return true;
    }).toList();

    final List<TripPhoto> imported = [];

    for (final asset in toProcess) {
      final file = await asset.file;
      if (file == null) continue;

      try {
        final tripPhoto = await _processPhoto(asset, file, tripId);
        if (tripPhoto != null) {
          imported.add(tripPhoto);
          await SyncService.savePhotoRef(tripPhoto.toHiveMap());
          await SyncService.unlockCell(tripPhoto.hexId, tripId);
        }
      } catch (_) {
        // Skip photos that fail EXIF parsing / processing.
      }
    }

    // Advance the watermark so the next call only looks at truly new photos.
    await prefs.setInt(
      _kLastImportKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    return imported;
  }

  static Future<TripPhoto?> _processPhoto(
      AssetEntity asset, File file, String tripId) async {
    double? lat;
    double? lng;

    // Try EXIF GPS first
    try {
      final bytes = await file.readAsBytes();
      final exifData = await readExifFromBytes(bytes);

      if (exifData.containsKey('GPS GPSLatitude') &&
          exifData.containsKey('GPS GPSLongitude')) {
        lat = _parseGpsCoord(
          exifData['GPS GPSLatitude']!.values,
          exifData['GPS GPSLatitudeRef']?.printable ?? 'N',
        );
        lng = _parseGpsCoord(
          exifData['GPS GPSLongitude']!.values,
          exifData['GPS GPSLongitudeRef']?.printable ?? 'E',
        );
      }
    } catch (_) {
      // EXIF parsing failed
    }

    // Fallback: use asset's built-in location if available
    if ((lat == null || lng == null) && asset.latitude != null) {
      lat = asset.latitude;
      lng = asset.longitude;
    }

    if (lat == null || lng == null) return null;

    // Must be within an active area (France, or Lincoln NE in test mode)
    final prefs = await SharedPreferences.getInstance();
    final testMode = prefs.getBool('test_mode_lincoln') ?? false;
    if (!HexGridService.isInActiveArea(lat, lng, testMode: testMode)) return null;

    final hexId = HexGridService.latLngToHexId(lat, lng);

    // Generate thumbnail
    final String? thumbnailBase64 = await _generateThumbnail(file);

    return TripPhoto(
      id: _uuid.v4(),
      assetId: asset.id,
      localPath: file.path,
      hexId: hexId,
      lat: lat,
      lng: lng,
      takenAt: asset.createDateTime,
      tripId: tripId,
      thumbnailBase64: thumbnailBase64,
    );
  }

  static double _parseGpsCoord(dynamic values, String ref) {
    try {
      final list = values.toList();
      double deg = 0, min = 0, sec = 0;

      if (list.isNotEmpty) {
        final d = list[0];
        deg = (d.numerator as num).toDouble() / (d.denominator as num).toDouble();
      }
      if (list.length > 1) {
        final m = list[1];
        min = (m.numerator as num).toDouble() / (m.denominator as num).toDouble();
      }
      if (list.length > 2) {
        final s = list[2];
        sec = (s.numerator as num).toDouble() / (s.denominator as num).toDouble();
      }

      double result = deg + min / 60.0 + sec / 3600.0;
      if (ref == 'S' || ref == 'W') result = -result;
      return result;
    } catch (_) {
      return 0;
    }
  }

  static Future<String?> _generateThumbnail(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize to 50x50
      final thumbnail = img.copyResizeCropSquare(image, size: 50);
      final jpegBytes = img.encodeJpg(thumbnail, quality: 60);

      return base64Encode(jpegBytes);
    } catch (_) {
      return null;
    }
  }

  /// Capture photo from camera with current GPS coordinates
  static Future<TripPhoto?> captureAndSave({
    required File photoFile,
    required double lat,
    required double lng,
    required String tripId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final testMode = prefs.getBool('test_mode_lincoln') ?? false;
    if (!HexGridService.isInActiveArea(lat, lng, testMode: testMode)) return null;

    final hexId = HexGridService.latLngToHexId(lat, lng);
    final thumbnailBase64 = await _generateThumbnail(photoFile);

    final tripPhoto = TripPhoto(
      id: _uuid.v4(),
      assetId: 'camera_${DateTime.now().millisecondsSinceEpoch}',
      localPath: photoFile.path,
      hexId: hexId,
      lat: lat,
      lng: lng,
      takenAt: DateTime.now(),
      tripId: tripId,
      thumbnailBase64: thumbnailBase64,
    );

    await SyncService.savePhotoRef(tripPhoto.toHiveMap());
    await SyncService.unlockCell(hexId, tripId);

    return tripPhoto;
  }

  /// Get all photos for a specific hex cell
  static List<Map<String, dynamic>> getPhotosForHex(String hexId) {
    return SyncService.getPhotosForHex(hexId);
  }

  /// Get all local photos
  static List<Map<String, dynamic>> getAllPhotos() {
    return SyncService.getAllLocalPhotos();
  }

  /// Load full-size image bytes from local path
  static Future<Uint8List?> loadImageBytes(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
