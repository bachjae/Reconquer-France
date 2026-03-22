import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants.dart';
import '../../providers/map_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/hex_grid_service.dart';
import '../../widgets/emergency_fab.dart';
import '../../widgets/progress_badge.dart';
import 'hex_detail_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;
  bool _mapReady = false;
  String? _selectedHexId;
  StreamSubscription<String>? _cellUnlockSub;
  Timer? _viewportDebounce;

  // GeoJSON source IDs
  static const _lockedLayerId = 'locked-hexes';
  static const _unlockedLayerId = 'unlocked-hexes';
  static const _unlockedSourceId = 'unlocked-hex-source';
  static const _lockedSourceId = 'locked-hex-source';

  @override
  void initState() {
    super.initState();
    _cellUnlockSub = LocationService.onCellUnlocked.listen((hexId) {
      if (_mapReady) _updateHexLayer();
    });
  }

  @override
  void dispose() {
    _cellUnlockSub?.cancel();
    _viewportDebounce?.cancel();
    super.dispose();
  }

  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
    setState(() => _mapReady = true);
    _setupMapLayers();
    _centerOnFrance();
  }

  Future<void> _centerOnFrance() async {
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
            coordinates: Position(kFranceCenterLng, kFranceCenterLat)),
        zoom: kInitialZoom,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  Future<void> _setupMapLayers() async {
    if (_mapboxMap == null) return;

    // Add locked hex source (empty initially, populated on viewport change)
    await _mapboxMap!.style.addSource(GeoJsonSource(
      id: _lockedSourceId,
      data: '{"type":"FeatureCollection","features":[]}',
    ));

    // Add unlocked hex source
    await _mapboxMap!.style.addSource(GeoJsonSource(
      id: _unlockedSourceId,
      data: '{"type":"FeatureCollection","features":[]}',
    ));

    // Locked hex fill layer
    await _mapboxMap!.style.addLayer(FillLayer(
      id: _lockedLayerId,
      sourceId: _lockedSourceId,
      fillColor: kColorLockedHex,
      fillOpacity: 0.85,
      fillOutlineColor: kColorLockedHexBorder,
    ));

    // Unlocked hex fill layer (glowing green)
    await _mapboxMap!.style.addLayer(FillLayer(
      id: _unlockedLayerId,
      sourceId: _unlockedSourceId,
      fillColor: kColorUnlockedHex,
      fillOpacity: 0.8,
      fillOutlineColor: kColorAccent,
    ));

    // Initial viewport load
    await _updateViewportHexes();
  }

  Future<void> _updateViewportHexes() async {
    if (_mapboxMap == null) return;

    try {
      final camera = await _mapboxMap!.getCameraState();
      final zoom = camera.zoom;

      // Only show hex grid at appropriate zoom levels
      if (zoom < 8) {
        await _clearHexLayers();
        return;
      }

      final bounds = await _mapboxMap!.coordinateBoundsForCamera(
        CameraOptions(
          center: camera.center,
          zoom: zoom,
          bearing: camera.bearing,
          pitch: camera.pitch,
        ),
      );

      final north =
          bounds.northeast.coordinates.lat.toDouble();
      final south =
          bounds.southwest.coordinates.lat.toDouble();
      final east =
          bounds.northeast.coordinates.lng.toDouble();
      final west =
          bounds.southwest.coordinates.lng.toDouble();

      // Clamp to France bounds
      final clampedNorth =
          north.clamp(FRANCE_SOUTH, FRANCE_NORTH).toDouble();
      final clampedSouth =
          south.clamp(FRANCE_SOUTH, FRANCE_NORTH).toDouble();
      final clampedEast =
          east.clamp(FRANCE_WEST, FRANCE_EAST).toDouble();
      final clampedWest =
          west.clamp(FRANCE_WEST, FRANCE_EAST).toDouble();

      if (clampedNorth <= clampedSouth || clampedEast <= clampedWest) return;

      final allHexIds = HexGridService.getHexIdsInBounds(
        northLat: clampedNorth,
        southLat: clampedSouth,
        westLng: clampedWest,
        eastLng: clampedEast,
        paddingDeg: kViewportPaddingDeg,
      );

      // Limit to max visible hexes for performance
      final limitedHexIds = allHexIds.take(kMaxVisibleHexes).toList();

      final unlockedCells = ref.read(unlockedCellsProvider);

      final lockedFeatures = <Map<String, dynamic>>[];
      final unlockedFeatures = <Map<String, dynamic>>[];

      for (final hexId in limitedHexIds) {
        final corners = HexGridService.hexCornersToGeoJson(hexId);
        final feature = {
          'type': 'Feature',
          'id': hexId,
          'properties': {'hexId': hexId},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [corners],
          },
        };

        if (unlockedCells.contains(hexId)) {
          unlockedFeatures.add(feature);
        } else {
          lockedFeatures.add(feature);
        }
      }

      final lockedGeoJson = jsonEncode({
        'type': 'FeatureCollection',
        'features': lockedFeatures,
      });
      final unlockedGeoJson = jsonEncode({
        'type': 'FeatureCollection',
        'features': unlockedFeatures,
      });

      // Update sources
      await _mapboxMap!.style
          .setStyleSourceProperty(_lockedSourceId, 'data', lockedGeoJson);
      await _mapboxMap!.style
          .setStyleSourceProperty(_unlockedSourceId, 'data', unlockedGeoJson);
    } catch (_) {
      // Map may not be ready
    }
  }

  Future<void> _updateHexLayer() async {
    await _updateViewportHexes();
  }

  Future<void> _clearHexLayers() async {
    try {
      await _mapboxMap!.style.setStyleSourceProperty(
          _lockedSourceId, 'data',
          '{"type":"FeatureCollection","features":[]}');
      await _mapboxMap!.style.setStyleSourceProperty(
          _unlockedSourceId, 'data',
          '{"type":"FeatureCollection","features":[]}');
    } catch (_) {}
  }

  void _onMapTap(MapContentGestureContext ctx) {
    final point = ctx.point;
    final lat = point.coordinates.lat.toDouble();
    final lng = point.coordinates.lng.toDouble();

    if (!HexGridService.isInFrance(lat, lng)) return;

    final hexId = HexGridService.latLngToHexId(lat, lng);
    setState(() => _selectedHexId = hexId);

    // Animate camera to hex center
    final center = HexGridService.hexIdToCenter(hexId);
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
            coordinates: Position(center.longitude, center.latitude)),
        zoom: 14,
      ),
      MapAnimationOptions(duration: 500),
    );

    // Show bottom sheet
    _showHexDetailSheet(hexId);
  }

  void _showHexDetailSheet(String hexId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HexDetailSheet(hexId: hexId),
    );
  }

  void _onCameraChanged(CameraChangedEventData data) {
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(const Duration(milliseconds: 500), () {
      _updateViewportHexes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = ref.watch(unlockedCellsProvider).length;

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      body: Stack(
        children: [
          // Mapbox Map
          MapWidget(
            key: const ValueKey('mapbox-map'),
            styleUri: kMapboxDarkStyle,
            cameraOptions: CameraOptions(
              center: Point(
                  coordinates:
                      Position(kFranceCenterLng, kFranceCenterLat)),
              zoom: kInitialZoom,
            ),
            onMapCreated: _onMapCreated,
            onTapListener: _onMapTap,
            onCameraChangeListener: _onCameraChanged,
          ),

          // Top overlay bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(),
          ),

          // Progress badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            left: 0,
            right: 0,
            child: Center(
              child: ProgressBadge(unlockedCount: unlockedCount),
            ),
          ),

          // Location button
          Positioned(
            bottom: 100,
            right: 16,
            child: _LocationButton(
              onTap: () async {
                final pos = await LocationService.getCurrentPosition();
                if (pos != null && _mapboxMap != null) {
                  await _mapboxMap!.flyTo(
                    CameraOptions(
                      center: Point(
                          coordinates:
                              Position(pos.longitude, pos.latitude)),
                      zoom: 14,
                    ),
                    MapAnimationOptions(duration: 800),
                  );
                }
              },
            ),
          ),

          // Emergency FAB (Corn + Husker)
          const Positioned(
            bottom: 100,
            right: 16,
            child: EmergencyFAB(),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(refreshableProfileProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(kColorBackground).withOpacity(0.9),
            const Color(kColorBackground).withOpacity(0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          // Logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚜️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Reconquer',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(kColorAccent),
                      fontFamily: 'PlayfairDisplay',
                    ),
              ),
            ],
          ),
          const Spacer(),
          // Profile avatar
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(kColorAccent), width: 2),
              ),
              child: Center(
                child: Text(
                  profile.value?.avatarEmoji ?? '🌽',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LocationButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.only(bottom: 60),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(kColorAccent), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.my_location,
          color: Color(kColorAccent),
          size: 22,
        ),
      ),
    );
  }
}
