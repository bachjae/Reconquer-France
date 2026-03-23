import 'package:hive_flutter/hive_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Manages Mapbox offline tile region downloads for France.
class OfflineTileService {
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox('offline_tiles');
  }

  static bool get isFranceDownloaded =>
      _box.get('france_downloaded', defaultValue: false) as bool;

  static double get downloadProgress =>
      (_box.get('france_progress') as num?)?.toDouble() ?? 0.0;

  /// Initiates a tile region download for metropolitan France.
  /// [onProgress] receives 0.0–1.0 progress values.
  /// [onComplete] called when download finishes.
  /// [onError] called on failure.
  static Future<void> downloadFrance({
    required void Function(double progress) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) async {
    try {
      final tileStore = await TileStore.createDefault();

      // France bounding box
      final franceGeometry = {
        'type': 'Polygon',
        'coordinates': [
          [
            [-5.2, 41.3],
            [9.6, 41.3],
            [9.6, 51.1],
            [-5.2, 51.1],
            [-5.2, 41.3],
          ]
        ]
      };

      final loadOptions = TileRegionLoadOptions(
        geometry: franceGeometry,
        descriptorsOptions: [
          TilesetDescriptorOptions(
            styleURI: 'mapbox://styles/mapbox/dark-v11',
            minZoom: 0,
            maxZoom: 12,
          )
        ],
        acceptExpired: true,
        networkRestriction: NetworkRestriction.none,
      );

      await tileStore.loadTileRegion(
        'france-offline',
        loadOptions,
        (progress) {
          if (progress.requiredResourceCount > 0) {
            final p = progress.completedResourceCount /
                progress.requiredResourceCount;
            onProgress(p.clamp(0.0, 1.0));
            _box.put('france_progress', p);
          }
        },
      );
      await _box.put('france_downloaded', true);
      await _box.put('france_progress', 1.0);
      onComplete();
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Remove the downloaded France tile region.
  static Future<void> removeFrance() async {
    try {
      final tileStore = await TileStore.createDefault();
      await tileStore.removeTileRegion('france-offline');
      await _box.put('france_downloaded', false);
      await _box.put('france_progress', 0.0);
    } catch (_) {}
  }

  /// Returns approximate size in MB of a France tile pack (estimate).
  static String get estimatedSizeMb => '~280 MB';
}
