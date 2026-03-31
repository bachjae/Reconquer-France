import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../../providers/map_provider.dart';
import '../../providers/test_mode_provider.dart';
import '../../services/hex_grid_service.dart' hide LatLng;
import '../../services/offline_tile_service.dart';

class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() =>
      _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _waypoints = [];
  Set<String> _routeCells = {};

  void _onMapTap(TapPosition _, LatLng point) {
    final testMode = ref.read(testModeProvider);
    if (!HexGridService.isInActiveArea(point.latitude, point.longitude, testMode: testMode)) return;
    setState(() {
      _waypoints.add(point);
      _recomputeRoute();
    });
  }

  void _recomputeRoute() {
    if (_waypoints.length < 2) {
      _routeCells = {};
      return;
    }
    final cells = <String>{};
    for (int i = 0; i < _waypoints.length - 1; i++) {
      cells.addAll(_segmentCells(_waypoints[i], _waypoints[i + 1]));
    }
    _routeCells = cells;
  }

  /// Interpolate hex cells every ~400 m along a single segment.
  Set<String> _segmentCells(LatLng from, LatLng to) {
    final testMode = ref.read(testModeProvider);
    final hexIds = <String>{};
    final latDiff = to.latitude - from.latitude;
    final lngDiff = to.longitude - from.longitude;
    // Approximate degrees → km at ~47°N: 1° lat ≈ 111 km, 1° lng ≈ 75 km
    final distKm = sqrt(
      pow(latDiff * 111.0, 2) + pow(lngDiff * 75.0, 2),
    );
    final steps = max(2, (distKm / 0.4).ceil()); // step every 400 m
    for (int s = 0; s <= steps; s++) {
      final t = s / steps;
      final lat = from.latitude + latDiff * t;
      final lng = from.longitude + lngDiff * t;
      if (HexGridService.isInActiveArea(lat, lng, testMode: testMode)) {
        hexIds.add(HexGridService.latLngToHexId(lat, lng));
      }
    }
    return hexIds;
  }

  double _totalDistanceKm() {
    if (_waypoints.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < _waypoints.length - 1; i++) {
      final latDiff =
          (_waypoints[i + 1].latitude - _waypoints[i].latitude) * 111.0;
      final avgLat =
          (_waypoints[i].latitude + _waypoints[i + 1].latitude) / 2;
      final lngDiff = (_waypoints[i + 1].longitude - _waypoints[i].longitude) *
          111.0 *
          cos(avgLat * pi / 180);
      total += sqrt(latDiff * latDiff + lngDiff * lngDiff);
    }
    return total;
  }

  void _undoLast() {
    if (_waypoints.isEmpty) return;
    setState(() {
      _waypoints.removeLast();
      _recomputeRoute();
    });
  }

  void _clearRoute() {
    setState(() {
      _waypoints.clear();
      _routeCells = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCells = ref.watch(unlockedCellsProvider);
    final newCells = _routeCells.difference(unlockedCells).length;
    final alreadyUnlocked = _routeCells.intersection(unlockedCells).length;
    final distKm = _totalDistanceKm();

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      appBar: AppBar(
        backgroundColor: const Color(kColorBackground),
        title: Text(
          'Route Planner',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          if (_waypoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo, color: Color(kColorAccent)),
              tooltip: 'Undo last point',
              onPressed: _undoLast,
            ),
          if (_waypoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all, color: Colors.white54),
              tooltip: 'Clear route',
              onPressed: _clearRoute,
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ───────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  const LatLng(kFranceCenterLat, kFranceCenterLng),
              initialZoom: kInitialZoom,
              maxZoom: kMaxTileZoom.toDouble(),
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate: kTileUrlTemplate,
                subdomains: kTileSubdomains,
                userAgentPackageName: 'com.reconquer.france',
                tileProvider: OfflineTileService.tileProvider,
                maxZoom: kMaxTileZoom.toDouble(),
              ),

              // Route cell highlights
              if (_routeCells.isNotEmpty)
                PolygonLayer(
                  polygonCulling: true,
                  polygons: _routeCells.take(1000).map((hexId) {
                    final corners = HexGridService.hexCorners(hexId)
                        .map((p) => LatLng(p.latitude, p.longitude))
                        .toList();
                    final isUnlocked = unlockedCells.contains(hexId);
                    return Polygon(
                      points: corners,
                      color: isUnlocked
                          ? const Color(kColorUnlockedHex).withValues(alpha: 0.55)
                          : const Color(kColorAccent).withValues(alpha: 0.22),
                      borderColor: isUnlocked
                          ? const Color(kColorUnlockedHex)
                          : const Color(kColorAccent).withValues(alpha: 0.7),
                      borderStrokeWidth: 1.2,
                    );
                  }).toList(),
                ),

              // Route polyline
              if (_waypoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _waypoints,
                      color: const Color(kColorAccent),
                      strokeWidth: 2.5,
                    ),
                  ],
                ),

              // Waypoint markers
              if (_waypoints.isNotEmpty)
                MarkerLayer(
                  markers: _waypoints.asMap().entries.map((e) {
                    final idx = e.key;
                    final pt = e.value;
                    final isEnd = idx == _waypoints.length - 1;
                    final isStart = idx == 0;
                    return Marker(
                      point: pt,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(kColorBackground),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(kColorAccent),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            isStart
                                ? Icons.trip_origin
                                : (isEnd ? Icons.place : Icons.circle),
                            color: const Color(kColorAccent),
                            size: isStart || isEnd ? 14 : 8,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution(kTileAttribution),
                ],
              ),
            ],
          ),

          // ── Stats panel ───────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _StatsPanel(
              waypointCount: _waypoints.length,
              totalCells: _routeCells.length,
              newCells: newCells,
              alreadyUnlocked: alreadyUnlocked,
              distanceKm: distKm,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Panel ────────────────────────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  final int waypointCount;
  final int totalCells;
  final int newCells;
  final int alreadyUnlocked;
  final double distanceKm;

  const _StatsPanel({
    required this.waypointCount,
    required this.totalCells,
    required this.newCells,
    required this.alreadyUnlocked,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: const Border(
          top: BorderSide(color: Color(0xFF2A2A4E)),
        ),
      ),
      child: waypointCount == 0
          ? const Center(
              child: Text(
                '📍 Tap the map to place waypoints and plan your route',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            )
          : waypointCount == 1
              ? const Center(
                  child: Text(
                    'Tap again to add a second point',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Stat(
                          label: 'Distance',
                          value: '${distanceKm.toStringAsFixed(1)} km',
                        ),
                        _Stat(
                          label: 'New Cells',
                          value: '$newCells',
                          color: const Color(kColorAccent),
                        ),
                        _Stat(
                          label: 'Already Won',
                          value: '$alreadyUnlocked',
                          color: const Color(kColorUnlockedHex),
                        ),
                        _Stat(
                          label: 'Total Hexes',
                          value: '$totalCells',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalCells > 0
                            ? alreadyUnlocked / totalCells
                            : 0,
                        minHeight: 6,
                        backgroundColor: const Color(kColorLockedHex),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(kColorUnlockedHex),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      newCells == 0
                          ? 'You\'ve already conquered this entire route! 🏆'
                          : '$newCells new hex${newCells == 1 ? "" : "es"} waiting to be unlocked',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
