import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide LatLng;
import '../../core/constants.dart';
import '../../services/sync_service.dart';
import '../../services/hex_grid_service.dart';

class TripReplayScreen extends StatefulWidget {
  const TripReplayScreen({super.key});

  @override
  State<TripReplayScreen> createState() => _TripReplayScreenState();
}

class _TripReplayScreenState extends State<TripReplayScreen>
    with TickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  bool _mapReady = false;

  // Replay state
  late List<MapEntry<String, DateTime>> _timedCells;
  int _replayIndex = 0;
  bool _isPlaying = false;
  bool _isFinished = false;
  Timer? _replayTimer;
  late AnimationController _pulseController;

  // Speed multiplier (cells per second)
  double _speedMultiplier = 5.0;

  static const _replaySourceId = 'replay-source';
  static const _replayLayerId = 'replay-layer';
  static const _trailLayerId = 'replay-trail-layer';

  final Set<String> _revealedCells = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Load timestamps sorted by unlock time
    final timestamps = SyncService.getUnlockTimestamps();
    _timedCells = timestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
    setState(() => _mapReady = true);
    _setupLayers();
  }

  Future<void> _setupLayers() async {
    if (_mapboxMap == null) return;

    await _mapboxMap!.style.addSource(GeoJsonSource(
      id: _replaySourceId,
      data: '{"type":"FeatureCollection","features":[]}',
    ));

    // Trail layer (all previously visited cells, semi-transparent)
    await _mapboxMap!.style.addLayer(FillLayer(
      id: _trailLayerId,
      sourceId: _replaySourceId,
      fillColor: kColorUnlockedHex,
      fillOpacity: 0.5,
      fillOutlineColor: kColorAccent,
    ));
  }

  void _startReplay() {
    if (_timedCells.isEmpty) return;
    setState(() {
      _isPlaying = true;
      _isFinished = false;
      if (_replayIndex >= _timedCells.length) {
        _replayIndex = 0;
        _revealedCells.clear();
        _updateMap();
      }
    });
    _scheduleNext();
  }

  void _pauseReplay() {
    _replayTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _resetReplay() {
    _replayTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isFinished = false;
      _replayIndex = 0;
      _revealedCells.clear();
    });
    _updateMap();
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
            coordinates: Position(kFranceCenterLng, kFranceCenterLat)),
        zoom: kInitialZoom,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  void _scheduleNext() {
    if (_replayIndex >= _timedCells.length) {
      setState(() {
        _isPlaying = false;
        _isFinished = true;
      });
      return;
    }

    // Interval between cells based on speed
    final intervalMs = (1000.0 / _speedMultiplier).round();
    _replayTimer = Timer(Duration(milliseconds: intervalMs), _revealNextCell);
  }

  void _revealNextCell() {
    if (_replayIndex >= _timedCells.length) {
      setState(() {
        _isPlaying = false;
        _isFinished = true;
      });
      return;
    }

    final hexId = _timedCells[_replayIndex].key;
    _revealedCells.add(hexId);
    setState(() => _replayIndex++);
    _updateMap();

    // Pan camera to newly revealed cell
    final center = HexGridService.hexIdToCenter(hexId);
    _mapboxMap?.easeTo(
      CameraOptions(
        center: Point(
            coordinates: Position(center.longitude, center.latitude)),
        zoom: 11,
      ),
      MapAnimationOptions(duration: 300),
    );

    if (_isPlaying) _scheduleNext();
  }

  Future<void> _updateMap() async {
    if (_mapboxMap == null) return;

    final features = _revealedCells.map((hexId) {
      final corners = HexGridService.hexCornersToGeoJson(hexId);
      return {
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [corners],
        },
      };
    }).toList();

    final geoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    try {
      await _mapboxMap!.style
          .setStyleSourceProperty(_replaySourceId, 'data', geoJson);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final progress = _timedCells.isEmpty
        ? 0.0
        : _replayIndex / _timedCells.length;

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      appBar: AppBar(
        backgroundColor: const Color(kColorBackground),
        title: Text(
          'Trip Replay',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontFamily: 'PlayfairDisplay'),
        ),
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            child: Stack(
              children: [
                MapWidget(
                  key: const ValueKey('replay-map'),
                  styleUri: kMapboxDarkStyle,
                  cameraOptions: CameraOptions(
                    center: Point(
                        coordinates:
                            Position(kFranceCenterLng, kFranceCenterLat)),
                    zoom: kInitialZoom,
                  ),
                  onMapCreated: _onMapCreated,
                ),

                // Cell counter overlay
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(kColorAccent).withOpacity(0.5)),
                      ),
                      child: Text(
                        '${_revealedCells.length} / ${_timedCells.length} cells',
                        style: const TextStyle(
                          color: Color(kColorAccent),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                // Finished overlay
                if (_isFinished)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(kColorAccent), width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('⚜️',
                              style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            'Conquest Complete!',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: const Color(kColorAccent)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_timedCells.length} cells unlocked',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Controls panel
          Container(
            color: const Color(0xFF0F0F1A),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                // Progress bar
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFF2A2A4E),
                  valueColor: const AlwaysStoppedAnimation(Color(kColorAccent)),
                  minHeight: 4,
                ),
                const SizedBox(height: 16),

                // Speed slider
                Row(
                  children: [
                    const Icon(Icons.speed,
                        size: 16, color: Colors.white54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _speedMultiplier,
                        min: 1.0,
                        max: 30.0,
                        divisions: 29,
                        activeColor: const Color(kColorAccent),
                        inactiveColor: const Color(0xFF2A2A4E),
                        onChanged: (v) =>
                            setState(() => _speedMultiplier = v),
                        label: '${_speedMultiplier.toInt()}x',
                      ),
                    ),
                    Text(
                      '${_speedMultiplier.toInt()}x',
                      style: const TextStyle(
                          color: Color(kColorAccent), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Playback buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Reset
                    IconButton(
                      onPressed: _resetReplay,
                      icon: const Icon(Icons.skip_previous_rounded),
                      color: Colors.white70,
                      iconSize: 32,
                    ),
                    const SizedBox(width: 16),

                    // Play/Pause
                    GestureDetector(
                      onTap: _timedCells.isEmpty
                          ? null
                          : (_isPlaying ? _pauseReplay : _startReplay),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _timedCells.isEmpty
                              ? Colors.white12
                              : const Color(kColorAccent),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Skip to end
                    IconButton(
                      onPressed: () {
                        _replayTimer?.cancel();
                        _revealedCells.clear();
                        _revealedCells
                            .addAll(_timedCells.map((e) => e.key));
                        setState(() {
                          _replayIndex = _timedCells.length;
                          _isPlaying = false;
                          _isFinished = true;
                        });
                        _updateMap();
                      },
                      icon: const Icon(Icons.skip_next_rounded),
                      color: Colors.white70,
                      iconSize: 32,
                    ),
                  ],
                ),

                if (_timedCells.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Explore France to build your replay!',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white38),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
