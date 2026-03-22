import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import 'hex_grid_service.dart';
import 'sync_service.dart';
import '../models/trip_photo.dart';
import '../core/constants.dart';

class PhotoService {
  static const _uuid = Uuid();

  /// Import photos from device library with EXIF GPS parsing
  static Future<List<TripPhoto>> importPhotosFromLibrary(String tripId) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      PhotoManager.openSetting();
      return [];
    }

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return [];

    final allPhotos = await albums.first
        .getAssetListRange(start: 0, end: 9999);

    final List<TripPhoto> imported = [];

    for (final asset in allPhotos) {
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
        // Skip photos that fail EXIF parsing
      }
    }

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

    // Must be within France
    if (!HexGridService.isInFrance(lat, lng)) return null;

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
    if (!HexGridService.isInFrance(lat, lng)) return null;

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
