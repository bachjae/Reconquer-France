import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../providers/map_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/test_mode_provider.dart';
import '../../services/location_service.dart';
import '../../services/hex_grid_service.dart' hide LatLng;
import '../../services/offline_tile_service.dart';
import '../../widgets/emergency_fab.dart';
import '../../widgets/progress_badge.dart';
import '../../widgets/streak_badge.dart';
import 'hex_detail_sheet.dart';
import 'trip_replay_screen.dart';
import 'collaborative_map_screen.dart';
import 'route_planner_screen.dart';

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
  StreamSubscription<dynamic>? _locationSub;
  Timer? _viewportDebounce;

  // Live location dot
  LatLng? _currentPosition;

  // Camera animation
  late AnimationController _animController;

  // Heatmap toggle
  bool _heatmapEnabled = false;

  // Cached polygon lists (rebuilt on camera move)
  List<Polygon> _lockedPolygons = [];
  List<Polygon> _unlockedPolygons = [];

  // Heatmap circles
  List<CircleMarker> _heatmapCircles = [];

  // Low-zoom conquest dots (shown when zoom < 8 to maintain fog of war)
  List<CircleMarker> _lowZoomDots = [];

  // Friends' cell overlay
  bool _showFriendCells = false;
  List<Polygon> _friendPolygons = [];

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
    _locationSub = LocationService.onPositionUpdate.listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
        });
      }
    });
    // Start position updates so My Location button and cell tracking work
    // even before a trip is created.
    LocationService.startPositionUpdatesOnly();
  }

  @override
  void dispose() {
    _cellUnlockSub?.cancel();
    _locationSub?.cancel();
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
    final testMode = ref.read(testModeProvider);

    if (zoom < 8.0) {
      // Below hex-detail zoom: clear polygons but show conquered cells as dots
      // so France stays fogged and the user can see their progress.
      final unlockedCells = ref.read(unlockedCellsProvider);
      setState(() {
        _lockedPolygons = [];
        _unlockedPolygons = [];
        _heatmapCircles = [];
        _lowZoomDots = unlockedCells.take(3000).map((hexId) {
          final center = HexGridService.hexIdToCenter(hexId);
          return CircleMarker(
            point: LatLng(center.latitude, center.longitude),
            radius: 5,
            color: const Color(kColorUnlockedHex).withValues(alpha: 0.9),
            borderColor: const Color(kColorAccent).withValues(alpha: 0.5),
            borderStrokeWidth: 0.8,
            useRadiusInMeter: false,
          );
        }).toList();
      });
      return;
    }

    final bounds = camera.visibleBounds;
    final unlockedCells = ref.read(unlockedCellsProvider);

    // At high zoom the viewport is tiny, so a large padding wastes the entire
    // take(kMaxVisibleHexes) budget on rows outside the visible area.
    final paddingDeg = zoom >= 11 ? 0.05 : kViewportPaddingDeg;

    // In test mode, render hexes wherever the camera is (no France clamping)
    final hexIds = testMode
        ? HexGridService.getHexIdsInBounds(
            northLat: bounds.north,
            southLat: bounds.south,
            westLng: bounds.west,
            eastLng: bounds.east,
            paddingDeg: paddingDeg,
          ).take(kMaxVisibleHexes)
        : HexGridService.getHexIdsInBounds(
            northLat: bounds.north.clamp(FRANCE_SOUTH, FRANCE_NORTH),
            southLat: bounds.south.clamp(FRANCE_SOUTH, FRANCE_NORTH),
            westLng: bounds.west.clamp(FRANCE_WEST, FRANCE_EAST),
            eastLng: bounds.east.clamp(FRANCE_WEST, FRANCE_EAST),
            paddingDeg: paddingDeg,
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
          color: const Color(kColorUnlockedHex),
          borderColor: const Color(kColorAccent),
          borderStrokeWidth: 1.5,
        ));
      } else {
        locked.add(Polygon(
          points: corners,
          color: const Color(kColorLockedHex).withValues(alpha: 0.85),
          borderColor: const Color(kColorLockedHexBorder),
          borderStrokeWidth: 0.4,
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
          color: Colors.deepOrange.withValues(alpha: 0.12),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
          useRadiusInMeter: false,
        );
      }).toList();
    }

    // Friends' cell polygons — shown only when the toggle is on and at
    // sufficient zoom so individual hexes are distinguishable.
    final friendPolys = <Polygon>[];
    if (_showFriendCells) {
      final friendsData =
          ref.read(friendsCellsProvider).value ?? const {};
      // Merge all friends' cells, skip cells the current user already owns.
      final allFriendHexIds = friendsData.values
          .expand((s) => s)
          .where((h) => !unlockedCells.contains(h))
          .toSet();

      for (final hexId in allFriendHexIds.take(kMaxVisibleHexes ~/ 2)) {
        // Cheap viewport cull before computing corners.
        final center = HexGridService.hexIdToCenter(hexId);
        if (center.latitude < bounds.south - 0.1 ||
            center.latitude > bounds.north + 0.1 ||
            center.longitude < bounds.west - 0.1 ||
            center.longitude > bounds.east + 0.1) continue;

        final corners = HexGridService.hexCorners(hexId)
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        friendPolys.add(Polygon(
          points: corners,
          color: const Color(kColorFriendHex),
          borderColor: Colors.blue.shade300.withValues(alpha: 0.4),
          borderStrokeWidth: 0.5,
        ));
      }
    }

    setState(() {
      _lockedPolygons = locked;
      _unlockedPolygons = unlocked;
      _heatmapCircles = circles;
      _friendPolygons = friendPolys;
      _lowZoomDots = [];
    });
  }

  // ── Map tap ─────────────────────────────────────────────────────────────────

  void _onMapTap(TapPosition _, LatLng point) {
    final testMode = ref.read(testModeProvider);
    if (!HexGridService.isInActiveArea(point.latitude, point.longitude, testMode: testMode)) return;

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
    // Re-render friend cells when Firestore data updates
    ref.listen(friendsCellsProvider, (_, __) {
      if (_showFriendCells && _mapReady) _rebuildViewportHexes();
    });
    final unlockedCount = ref.watch(unlockedCellsProvider).length;

    final testMode = ref.watch(testModeProvider);
    // Keep LocationService in sync with test mode state
    LocationService.testMode = testMode;
    // React to test mode toggling on — jump to the right area
    ref.listen(testModeProvider, (prev, next) {
      if (!_mapReady) return;
      if (next) {
        _animateTo(const LatLng(LINCOLN_CENTER_LAT, LINCOLN_CENTER_LNG), 13.0);
      } else {
        _animateTo(const LatLng(kFranceCenterLat, kFranceCenterLng), kInitialZoom);
      }
    });

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      body: Stack(
        children: [
          // ── Flutter Map ──────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: testMode
                  ? const LatLng(LINCOLN_CENTER_LAT, LINCOLN_CENTER_LNG)
                  : const LatLng(kFranceCenterLat, kFranceCenterLng),
              initialZoom: testMode ? 13.0 : kInitialZoom,
              minZoom: 4.5,
              maxZoom: kMaxTileZoom.toDouble(),
              onMapReady: () {
                setState(() {
                  _mapReady = true;
                  _rebuildViewportHexes();
                });
                // If test mode was already active when map loaded, jump to Lincoln
                final isTestMode = ref.read(testModeProvider);
                if (isTestMode) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _animateTo(
                      const LatLng(LINCOLN_CENTER_LAT, LINCOLN_CENTER_LNG),
                      13.0,
                    );
                  });
                }
              },
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

              // France fog overlay — persists at ALL zoom levels so the map
              // never reveals all of France. Unlocked hexes render on top.
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: [
                      LatLng(FRANCE_NORTH, FRANCE_WEST),
                      LatLng(FRANCE_NORTH, FRANCE_EAST),
                      LatLng(FRANCE_SOUTH, FRANCE_EAST),
                      LatLng(FRANCE_SOUTH, FRANCE_WEST),
                    ],
                    color: const Color(kColorBackground).withValues(alpha: 0.82),
                  ),
                ],
              ),

              // Lincoln fog overlay (test mode only)
              if (testMode)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: [
                        LatLng(LINCOLN_NORTH, LINCOLN_WEST),
                        LatLng(LINCOLN_NORTH, LINCOLN_EAST),
                        LatLng(LINCOLN_SOUTH, LINCOLN_EAST),
                        LatLng(LINCOLN_SOUTH, LINCOLN_WEST),
                      ],
                      color: const Color(kColorBackground).withValues(alpha: 0.82),
                    ),
                  ],
                ),

              // Low-zoom conquest dots (zoom < 8): shows conquered cells
              // as glowing dots through the fog without rendering all hexes.
              if (_lowZoomDots.isNotEmpty)
                CircleLayer(circles: _lowZoomDots),

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

              // Friends' conquered cells (blue overlay, toggled via button)
              if (_showFriendCells && _friendPolygons.isNotEmpty)
                PolygonLayer(
                  polygons: _friendPolygons,
                  polygonCulling: true,
                ),

              // Live location dot — always on top
              if (_currentPosition != null)
                CircleLayer(
                  circles: [
                    // Accuracy halo
                    CircleMarker(
                      point: _currentPosition!,
                      radius: 24,
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderColor: Colors.blue.withValues(alpha: 0.3),
                      borderStrokeWidth: 1,
                      useRadiusInMeter: false,
                    ),
                    // Position dot
                    CircleMarker(
                      point: _currentPosition!,
                      radius: 7,
                      color: Colors.blue.shade400,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                      useRadiusInMeter: false,
                    ),
                  ],
                ),
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
              child: ProgressBadge(unlockedCount: unlockedCount, testMode: testMode),
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
                const SizedBox(height: 6),
                _MapIconButton(
                  icon: Icons.play_circle_outline,
                  tooltip: 'Trip Replay',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TripReplayScreen()),
                  ),
                ),
                const SizedBox(height: 6),
                _MapIconButton(
                  icon: _showFriendCells
                      ? Icons.people
                      : Icons.people_outline,
                  color: _showFriendCells
                      ? Colors.blue.shade400
                      : const Color(kColorAccent),
                  tooltip: _showFriendCells
                      ? 'Hide Friends'
                      : 'Show Friends',
                  onTap: () {
                    setState(() => _showFriendCells = !_showFriendCells);
                    _rebuildViewportHexes();
                  },
                ),
                const SizedBox(height: 6),
                _MapIconButton(
                  icon: Icons.group_outlined,
                  tooltip: 'Group Map',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CollaborativeMapScreen()),
                  ),
                ),
                const SizedBox(height: 6),
                _MapIconButton(
                  icon: Icons.route_outlined,
                  tooltip: 'Route Planner',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RoutePlannerScreen()),
                  ),
                ),
                const SizedBox(height: 6),
                _MapIconButton(
                  icon: Icons.ios_share,
                  tooltip: 'Export & Share',
                  onTap: () => context.push('/export'),
                ),
                const SizedBox(height: 6),
                _MapIconButton(
                  icon: Icons.my_location,
                  tooltip: 'My Location',
                  onTap: () async {
                    // Try last known position first for instant feedback
                    final last = LocationService.lastPosition;
                    if (last != null && mounted) {
                      _animateTo(LatLng(last.latitude, last.longitude), 14);
                      return;
                    }
                    final pos = await LocationService.getCurrentPosition();
                    if (pos != null && mounted) {
                      _animateTo(LatLng(pos.latitude, pos.longitude), 14);
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Location unavailable — check permissions'),
                          duration: Duration(seconds: 3),
                        ),
                      );
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

          // ── Test mode banner ─────────────────────────────────────────────
          if (testMode)
            Positioned(
              bottom: 170,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '🧪 TEST MODE — Lincoln NE',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
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
            const Color(kColorBackground).withValues(alpha: 0.9),
            const Color(kColorBackground).withValues(alpha: 0.0),
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
