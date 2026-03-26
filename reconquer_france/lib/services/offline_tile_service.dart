import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';

/// Manages offline tile caching for France using flutter_map_tile_caching (FMTC) v9.
/// No API key or credit card required — uses free CartoDB Dark Matter tiles.
class OfflineTileService {
  static const _storeName = 'reconquer_france_tiles';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox('offline_tiles');
    // Ensure the FMTC tile store exists
    try {
      final store = FMTCStore(_storeName);
      await store.manage.create();
    } catch (_) {
      // FMTC init failure is non-fatal; online tiles still work
    }
  }

  /// Returns a tile provider that serves cached tiles first, falls back online.
  static TileProvider get tileProvider {
    return FMTCStore(_storeName).getTileProvider(
      settings: FMTCTileProviderSettings(
        behavior: CacheBehavior.cacheFirst,
      ),
    );
  }

  static bool get isFranceDownloaded =>
      _box.get('france_downloaded', defaultValue: false) as bool;

  static double get downloadProgress =>
      (_box.get('france_progress') as num?)?.toDouble() ?? 0.0;

  /// Downloads all France tiles for zoom 0–12 (~280 MB).
  static Future<void> downloadFrance({
    required void Function(double progress, int downloaded, int total)
        onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) async {
    try {
      final store = FMTCStore(_storeName);

      // France bounding box
      final region = RectangleRegion(
        LatLngBounds(
          const LatLng(51.1, 9.6), // NE
          const LatLng(41.3, -5.2), // SW
        ),
      );

      final downloadable = region.toDownloadable(
        minZoom: 0,
        maxZoom: 12,
        options: TileLayer(
          urlTemplate: kTileUrlTemplate,
          subdomains: kTileSubdomains,
        ),
      );

      await for (final progress
          in store.download.startForeground(region: downloadable)) {
        final p = progress.percentageProgress / 100.0;
        onProgress(
          p.clamp(0.0, 1.0),
          progress.successfulTiles,
          progress.maxTiles,
        );
        await _box.put('france_progress', p);
        if (progress.isComplete) break;
      }

      await _box.put('france_downloaded', true);
      await _box.put('france_progress', 1.0);
      onComplete();
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Cancel any active download.
  static Future<void> cancelDownload() async {
    try {
      await FMTCStore(_storeName).download.cancel();
    } catch (_) {}
  }

  /// Delete all cached tiles for France and reset download state.
  static Future<void> removeFrance() async {
    try {
      await FMTCStore(_storeName).manage.delete();
      await FMTCStore(_storeName).manage.create();
    } catch (_) {}
    await _box.put('france_downloaded', false);
    await _box.put('france_progress', 0.0);
  }

  static String get estimatedSizeMb => '~280 MB';
}
