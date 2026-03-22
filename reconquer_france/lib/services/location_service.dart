import 'dart:async';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:geolocator/geolocator.dart';
import 'hex_grid_service.dart';
import 'sync_service.dart';
import '../core/constants.dart';

class LocationService {
  static final Map<String, DateTime> _dwellTimers = {};
  static StreamController<String> _cellUnlockController =
      StreamController<String>.broadcast();
  static StreamController<LatLng> _positionController =
      StreamController<LatLng>.broadcast();

  static Stream<String> get onCellUnlocked => _cellUnlockController.stream;
  static Stream<LatLng> get onPositionUpdate => _positionController.stream;

  static LatLng? _lastPosition;
  static LatLng? get lastPosition => _lastPosition;

  static String? _currentTripId;

  static Future<void> initialize(String tripId) async {
    _currentTripId = tripId;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    await bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: kDistanceFilterMeters,
      stopOnTerminate: false,
      startOnBoot: true,
      enableHeadless: true,
      logLevel: bg.Config.LOG_LEVEL_OFF,
      notification: bg.Notification(
        title: 'Reconquer France',
        text: 'Tracking your conquest...',
        smallIcon: 'drawable/ic_flag',
        color: '#E8C547',
      ),
      // Battery-saving config
      activityType: bg.Config.ACTIVITY_TYPE_FITNESS,
      pausesLocationUpdatesAutomatically: false,
      preventSuspend: true,
    ));

    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      final lat = location.coords.latitude;
      final lng = location.coords.longitude;
      final pos = LatLng(lat, lng);

      _lastPosition = pos;
      _positionController.add(pos);

      // Only process cells within France
      if (HexGridService.isInFrance(lat, lng)) {
        final hexId = HexGridService.latLngToHexId(lat, lng);
        _handleCellVisit(hexId);
      }
    });

    bg.BackgroundGeolocation.onMotionChange((bg.Location location) {
      // Clear dwell timers when motion changes
      _dwellTimers.clear();
    });

    await bg.BackgroundGeolocation.start();
  }

  static void _handleCellVisit(String hexId) {
    // Already unlocked — no need to dwell
    if (SyncService.isCellUnlocked(hexId)) return;

    if (!_dwellTimers.containsKey(hexId)) {
      _dwellTimers[hexId] = DateTime.now();
    } else {
      final elapsed = DateTime.now().difference(_dwellTimers[hexId]!);
      if (elapsed.inSeconds >= kDwellSecondsRequired) {
        _unlockCell(hexId);
        _dwellTimers.remove(hexId);
        // Remove all other dwell timers for cleanup
        _dwellTimers.removeWhere((k, v) =>
            DateTime.now().difference(v).inMinutes > 5);
      }
    }
  }

  static Future<void> _unlockCell(String hexId) async {
    if (_currentTripId == null) return;
    await SyncService.unlockCell(hexId, _currentTripId!);
    _cellUnlockController.add(hexId);
  }

  static Future<void> stop() async {
    await bg.BackgroundGeolocation.stop();
    _dwellTimers.clear();
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  static void dispose() {
    _cellUnlockController.close();
    _positionController.close();
    _cellUnlockController = StreamController<String>.broadcast();
    _positionController = StreamController<LatLng>.broadcast();
  }
}
