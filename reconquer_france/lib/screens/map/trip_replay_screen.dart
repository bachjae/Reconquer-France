import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../../services/sync_service.dart';
import '../../services/hex_grid_service.dart';
import '../../services/offline_tile_service.dart';

class TripReplayScreen extends StatefulWidget {
  const TripReplayScreen({super.key});

  @override
  State<TripReplayScreen> createState() => _TripReplayScreenState();
}

class _TripReplayScreenState extends State<TripReplayScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  // Sorted list of (hexId, unlockTime)
  late List<MapEntry<String, DateTime>> _timedCells;
  int _replayIndex = 0;
  bool _isPlaying = false;
  bool _isFinished = false;
  Timer? _replayTimer;

  double _speedMultiplier = 5.0;

  // Camera animation
  late AnimationController _animController;

  final Set<String> _revealedCells = {};
  List<Polygon> _polygons = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    final timestamps = SyncService.getUnlockTimestamps();
    _timedCells = timestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _animateTo(LatLng dest, double zoom) {
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    final latTween =
        Tween<double>(begin: startCenter.latitude, end: dest.latitude);
    final lngTween =
        Tween<double>(begin: startCenter.longitude, end: dest.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: zoom);
    final curve =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    void listener() {
      _mapController.move(
        LatLng(latTween.evaluate(curve), lngTween.evaluate(curve)),
        zoomTween.evaluate(curve),
      );
    }

    _animController
      ..reset()
      ..addListener(listener)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed ||
            s == AnimationStatus.dismissed) {
          _animController.removeListener(listener);
        }
      })
      ..forward();
  }

  void _startReplay() {
    if (_timedCells.isEmpty) return;
    setState(() {
      _isPlaying = true;
      _isFinished = false;
      if (_replayIndex >= _timedCells.length) {
        _replayIndex = 0;
        _revealedCells.clear();
        _polygons = [];
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
      _polygons = [];
    });
    if (_mapReady) {
      _mapController.move(
        const LatLng(kFranceCenterLat, kFranceCenterLng),
        kInitialZoom,
      );
    }
  }

  void _scheduleNext() {
    if (_replayIndex >= _timedCells.length) {
      setState(() {
        _isPlaying = false;
        _isFinished = true;
      });
      return;
    }
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
    _replayIndex++;

    // Rebuild polygon list incrementally
    final corners = HexGridService.hexCorners(hexId)
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    _polygons.add(Polygon(
      points: corners,
      color: const Color(kColorUnlockedHex).withOpacity(0.75),
      borderColor: const Color(kColorAccent),
      borderStrokeWidth: 0.8,
      isFilled: true,
    ));

    setState(() {});

    // Pan to revealed cell
    final center = HexGridService.hexIdToCenter(hexId);
    if (_mapReady) {
      _animateTo(LatLng(center.latitude, center.longitude), 11);
    }

    if (_isPlaying) _scheduleNext();
  }

  void _skipToEnd() {
    _replayTimer?.cancel();
    for (int i = _replayIndex; i < _timedCells.length; i++) {
      final hexId = _timedCells[i].key;
      _revealedCells.add(hexId);
      final corners = HexGridService.hexCorners(hexId)
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      _polygons.add(Polygon(
        points: corners,
        color: const Color(kColorUnlockedHex).withOpacity(0.75),
        borderColor: const Color(kColorAccent),
        borderStrokeWidth: 0.8,
        isFilled: true,
      ));
    }
    setState(() {
      _replayIndex = _timedCells.length;
      _isPlaying = false;
      _isFinished = true;
    });
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
          // ── Map ─────────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(
                        kFranceCenterLat, kFranceCenterLng),
                    initialZoom: kInitialZoom,
                    onMapReady: () => setState(() => _mapReady = true),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: kTileUrlTemplate,
                      subdomains: kTileSubdomains,
                      userAgentPackageName: 'com.reconquer.france',
                      tileProvider: OfflineTileService.tileProvider,
                    ),
                    PolygonLayer(
                      polygons: _polygons,
                      polygonCulling: true,
                    ),
                  ],
                ),

                // Cell counter
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
                            color:
                                const Color(kColorAccent).withOpacity(0.5)),
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
                                ?.copyWith(
                                    color: const Color(kColorAccent)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_timedCells.length} cells unlocked',
                            style:
                                Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Controls panel ───────────────────────────────────────────────
          Container(
            color: const Color(0xFF0F0F1A),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                // Progress bar
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFF2A2A4E),
                  valueColor: const AlwaysStoppedAnimation(
                      Color(kColorAccent)),
                  minHeight: 4,
                ),
                const SizedBox(height: 14),

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
                        max: 50.0,
                        divisions: 49,
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
                    IconButton(
                      onPressed: _resetReplay,
                      icon: const Icon(Icons.skip_previous_rounded),
                      color: Colors.white70,
                      iconSize: 32,
                    ),
                    const SizedBox(width: 16),
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
                    IconButton(
                      onPressed: _skipToEnd,
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
