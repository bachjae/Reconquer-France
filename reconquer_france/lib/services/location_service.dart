import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'hex_grid_service.dart';
import 'sync_service.dart';
import 'elevation_service.dart';


class LocationService {
  /// Set to true to also unlock cells in Lincoln NE (test mode)
  static bool testMode = false;

  static StreamController<String> _cellUnlockController =
      StreamController<String>.broadcast();
  static StreamController<LatLng> _positionController =
      StreamController<LatLng>.broadcast();

  static Stream<String> get onCellUnlocked => _cellUnlockController.stream;
  static Stream<LatLng> get onPositionUpdate => _positionController.stream;

  static LatLng? _lastPosition;
  static LatLng? get lastPosition => _lastPosition;

  static String? _currentTripId;

  static StreamSubscription<Position>? _fallbackSub;

  /// Start location tracking for an active trip (unlocks cells on dwell).
  static Future<void> initialize(String tripId) async {
    _currentTripId = tripId;
    await _ensureStreamRunning();
  }

  /// Start position updates without a trip (for My Location button / map use).
  /// Safe to call multiple times — no-ops if stream is already running.
  static Future<void> startPositionUpdatesOnly() async {
    await _ensureStreamRunning();
  }

  static Future<void> _ensureStreamRunning() async {
    if (_fallbackSub != null) return; // already running

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    if (!kIsWeb && Platform.isAndroid) {
      // Request "Allow all the time" location for background tracking.
      // This is needed on Android 10+ for location access when screen is locked.
      final bgStatus = await Permission.locationAlways.status;
      if (bgStatus.isDenied) {
        await Permission.locationAlways.request();
      }

      // Exempt from Doze mode so the foreground service fires even on battery saver.
      if (!await Permission.ignoreBatteryOptimizations.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    _startFallbackStream();
  }

  static void _startFallbackStream() {
    _fallbackSub?.cancel();

    final LocationSettings settings;
    if (!kIsWeb && Platform.isAndroid) {
      settings = AndroidSettings(
        // medium = WiFi/cell tower triangulation — accurate to ~50 m, much
        // cheaper than GPS. Hex cells are ~200 m wide so this is plenty.
        accuracy: LocationAccuracy.medium,
        // Only wake up when the user has actually moved 50 m.
        distanceFilter: 50,
        // Never poll faster than every 30 s regardless of distance.
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Reconquer France',
          notificationText: 'Tracking location to unlock hexes',
          // Wake lock disabled — the foreground service notification keeps
          // the process alive; we don't need the CPU awake between 50 m
          // distance-filter events.
          enableWakeLock: false,
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        ),
      );
    } else if (!kIsWeb && Platform.isIOS) {
      // AppleSettings lets us opt into the always-on background location
      // mode and prevent iOS from pausing updates when it thinks the user
      // has stopped moving.
      settings = AppleSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 50,
        // fitness = walking/cycling — tells CoreLocation we care about
        // movement on foot, which prevents automatic pausing.
        activityType: ActivityType.fitness,
        // Never let iOS pause updates automatically; we rely on the
        // distance filter for power savings instead.
        pauseLocationUpdatesAutomatically: false,
        // Keep background location updates alive while the app is backgrounded.
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 50,
      );
    }

    _fallbackSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
      (Position pos) {
        _onPosition(pos.latitude, pos.longitude,
            altitude: pos.altitude, altAccuracy: pos.altitudeAccuracy);
      },
      onError: (_) {},
    );
  }

  static void _onPosition(double lat, double lng,
      {double altitude = 0, double altAccuracy = 0}) {
    final pos = LatLng(lat, lng);
    _lastPosition = pos;
    _positionController.add(pos);
    ElevationService.recordAltitude(altitude, altitudeAccuracy: altAccuracy);
    if (HexGridService.isInActiveArea(lat, lng, testMode: testMode)) {
      _handleCellVisit(HexGridService.latLngToHexId(lat, lng));
    }
  }

  static void _handleCellVisit(String hexId) {
    if (SyncService.isCellUnlocked(hexId)) return;
    _unlockCell(hexId);
  }

  static Future<void> _unlockCell(String hexId) async {
    // Unlock locally even without a trip — cells are saved to Hive and will
    // sync to Firestore once a real trip is created via trip setup.
    final tripId = _currentTripId ?? 'local';
    await SyncService.unlockCell(hexId, tripId);
    _cellUnlockController.add(hexId);
  }

  /// Re-process the last known position — useful when test mode toggles on
  /// so a stationary user immediately gets credit for their current cell.
  static void recheckLastPosition() {
    if (_lastPosition == null) return;
    _onPosition(_lastPosition!.latitude, _lastPosition!.longitude);
  }

  static Future<void> stop() async {
    await _fallbackSub?.cancel();
    _fallbackSub = null;
    _currentTripId = null;
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
        timeLimit: const Duration(seconds: 15),
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
