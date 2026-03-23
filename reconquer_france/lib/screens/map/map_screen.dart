import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../providers/map_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/hex_grid_service.dart' hide LatLng;
import '../../services/offline_tile_service.dart';
import '../../widgets/emergency_fab.dart';
import '../../widgets/progress_badge.dart';
import '../../widgets/streak_badge.dart';
import 'hex_detail_sheet.dart';
import 'trip_replay_screen.dart';
import 'collaborative_map_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _mapReady = false;
  StreamSubscription<String>? _cellUnlockSub;
  Timer? _viewportDebounce;

  // Camera animation
  late AnimationController _animController;

  // Heatmap toggle
  bool _heatmapEnabled = false;

  // Cached polygon lists (rebuilt on camera move)
  List<Polygon> _lockedPolygons = [];
  List<Polygon> _unlockedPolygons = [];

  // Heatmap circles
  List<CircleMarker> _heatmapCircles = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cellUnlockSub = LocationService.onCellUnlocked.listen((_) {
      if (_mapReady) _rebuildViewportHexes();
    });
  }

  @override
  void dispose() {
    _cellUnlockSub?.cancel();
    _viewportDebounce?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ── Camera animation ────────────────────────────────────────────────────────

  void _animateTo(LatLng dest, double zoom) {
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    final latTween =
        Tween<double>(begin: startCenter.latitude, end: dest.latitude);
    final lngTween =
        Tween<double>(begin: startCenter.longitude, end: dest.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: zoom);
    final curve =
        CurvedAnimation(parent: _animController, curve: Curves.easeInOut);

    void listener() {
      _mapController.move(
        LatLng(latTween.evaluate(curve), lngTween.evaluate(curve)),
        zoomTween.evaluate(curve),
      );
    }

    _animController
      ..reset()
      ..addListener(listener)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          _animController.removeListener(listener);
        }
      })
      ..forward();
  }

  // ── Viewport hex building ───────────────────────────────────────────────────

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _viewportDebounce?.cancel();
    _viewportDebounce =
        Timer(const Duration(milliseconds: 400), _rebuildViewportHexes);
  }

  void _rebuildViewportHexes() {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    final zoom = camera.zoom;

    if (zoom < 8.0) {
      setState(() {
        _lockedPolygons = [];
        _unlockedPolygons = [];
        _heatmapCircles = [];
      });
      return;
    }

    final bounds = camera.visibleBounds;
    final unlockedCells = ref.read(unlockedCellsProvider);

    final hexIds = HexGridService.getHexIdsInBounds(
      northLat: bounds.north.clamp(FRANCE_SOUTH, FRANCE_NORTH),
      southLat: bounds.south.clamp(FRANCE_SOUTH, FRANCE_NORTH),
      westLng: bounds.west.clamp(FRANCE_WEST, FRANCE_EAST),
      eastLng: bounds.east.clamp(FRANCE_WEST, FRANCE_EAST),
      paddingDeg: kViewportPaddingDeg,
    ).take(kMaxVisibleHexes);

    final locked = <Polygon>[];
    final unlocked = <Polygon>[];

    for (final hexId in hexIds) {
      final corners = HexGridService.hexCorners(hexId)
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      if (unlockedCells.contains(hexId)) {
        unlocked.add(Polygon(
          points: corners,
          color: const Color(kColorUnlockedHex).withOpacity(0.80),
          borderColor: const Color(kColorAccent),
          borderStrokeWidth: 0.8,
          isFilled: true,
        ));
      } else {
        locked.add(Polygon(
          points: corners,
          color: const Color(kColorLockedHex).withOpacity(0.85),
          borderColor: const Color(kColorLockedHexBorder),
          borderStrokeWidth: 0.4,
          isFilled: true,
        ));
      }
    }

    // Heatmap circles (sampled from all unlocked cells, not just viewport)
    List<CircleMarker> circles = [];
    if (_heatmapEnabled) {
      circles = unlockedCells.take(2000).map((hexId) {
        final center = HexGridService.hexIdToCenter(hexId);
        return CircleMarker(
          point: LatLng(center.latitude, center.longitude),
          radius: 14,
          color: Colors.deepOrange.withOpacity(0.12),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
          useRadiusInMeter: false,
        );
      }).toList();
    }

    setState(() {
      _lockedPolygons = locked;
      _unlockedPolygons = unlocked;
      _heatmapCircles = circles;
    });
  }

  // ── Map tap ─────────────────────────────────────────────────────────────────

  void _onMapTap(TapPosition _, LatLng point) {
    if (!HexGridService.isInFrance(point.latitude, point.longitude)) return;

    final hexId = HexGridService.latLngToHexId(point.latitude, point.longitude);
    final center = HexGridService.hexIdToCenter(hexId);
    _animateTo(LatLng(center.latitude, center.longitude), 14);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HexDetailSheet(hexId: hexId),
    );
  }

  // ── Heatmap toggle ──────────────────────────────────────────────────────────

  void _toggleHeatmap() {
    setState(() => _heatmapEnabled = !_heatmapEnabled);
    _rebuildViewportHexes();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Re-render polygons when unlocked cells change
    ref.listen(unlockedCellsProvider, (_, __) => _rebuildViewportHexes());
    final unlockedCount = ref.watch(unlockedCellsProvider).length;

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      body: Stack(
        children: [
          // ── Flutter Map ──────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  const LatLng(kFranceCenterLat, kFranceCenterLng),
              initialZoom: kInitialZoom,
              maxZoom: kMaxTileZoom.toDouble(),
              onMapReady: () => setState(() {
                _mapReady = true;
                _rebuildViewportHexes();
              }),
              onTap: _onMapTap,
              onPositionChanged: _onPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Tile layer — CartoDB Dark Matter (free, no key)
              TileLayer(
                urlTemplate: kTileUrlTemplate,
                subdomains: kTileSubdomains,
                userAgentPackageName: 'com.reconquer.france',
                tileProvider: OfflineTileService.tileProvider,
                maxZoom: kMaxTileZoom.toDouble(),
              ),

              // Attribution
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(kTileAttribution),
                ],
              ),

              // Locked hex polygons (fog of war)
              if (!_heatmapEnabled)
                PolygonLayer(
                  polygons: _lockedPolygons,
                  polygonCulling: true,
                ),

              // Unlocked hex polygons (conquered territory)
              if (!_heatmapEnabled)
                PolygonLayer(
                  polygons: _unlockedPolygons,
                  polygonCulling: true,
                ),

              // Heatmap density view (when toggled on)
              if (_heatmapEnabled)
                CircleLayer(circles: _heatmapCircles),
            ],
          ),

          // ── Top overlay bar ──────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(mapController: _mapController),
          ),

          // ── Progress badge ───────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            left: 0,
            right: 0,
            child: Center(
              child: ProgressBadge(unlockedCount: unlockedCount),
            ),
          ),

          // ── Streak badge (top right) ─────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            right: 72,
            child: const StreakBadge(compact: true),
          ),

          // ── Right-side button column ─────────────────────────────────────
          Positioned(
            bottom: 110,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapIconButton(
                  icon: _heatmapEnabled
                      ? Icons.whatshot
                      : Icons.whatshot_outlined,
                  color: _heatmapEnabled
                      ? Colors.deepOrange
                      : const Color(kColorAccent),
                  tooltip:
                      _heatmapEnabled ? 'Hide Heatmap' : 'Show Heatmap',
                  onTap: _toggleHeatmap,
                ),
                const SizedBox(height: 8),
                _MapIconButton(
                  icon: Icons.play_circle_outline,
                  tooltip: 'Trip Replay',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TripReplayScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                _MapIconButton(
                  icon: Icons.group_outlined,
                  tooltip: 'Group Map',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CollaborativeMapScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                _MapIconButton(
                  icon: Icons.my_location,
                  tooltip: 'My Location',
                  onTap: () async {
                    final pos = await LocationService.getCurrentPosition();
                    if (pos != null && mounted) {
                      _animateTo(
                          LatLng(pos.latitude, pos.longitude), 14);
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Emergency FAB (Corn + Husker) ────────────────────────────────
          const Positioned(
            bottom: 110,
            left: 16,
            child: EmergencyFAB(),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final MapController mapController;
  const _TopBar({required this.mapController});

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
          const Text('⚜️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            'Reconquer',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(kColorAccent),
                  fontFamily: 'PlayfairDisplay',
                ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                shape: BoxShape.circle,
                border:
                    Border.all(color: const Color(kColorAccent), width: 2),
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

// ── Map icon button ────────────────────────────────────────────────────────────

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String tooltip;

  const _MapIconButton({
    required this.icon,
    required this.onTap,
    this.color = const Color(kColorAccent),
    this.tooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
