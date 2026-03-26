import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

/// Tracks altitude and terrain statistics across the trip.
class ElevationService {
  static late Box _box;

  static final _updateController = StreamController<void>.broadcast();
  /// Fires after each altitude sample is recorded — used by ElevationNotifier.
  static Stream<void> get onUpdate => _updateController.stream;

  static const _keyMaxAltitude = 'maxAltitude';
  static const _keyMinAltitude = 'minAltitude';
  static const _keyTotalAscent = 'totalAscent';
  static const _keyTotalDescent = 'totalDescent';
  static const _keyLastAltitude = 'lastAltitude';
  static const _keySamplesCount = 'samplesCount';

  // In-memory last altitude for delta calculation
  static double? _lastAltitude;

  static Future<void> init() async {
    _box = await Hive.openBox('elevation_data');
    _lastAltitude = _box.get(_keyLastAltitude) as double?;
  }

  static double get maxAltitude =>
      (_box.get(_keyMaxAltitude) as num?)?.toDouble() ?? 0.0;
  static double get minAltitude =>
      (_box.get(_keyMinAltitude) as num?)?.toDouble() ?? 0.0;
  static double get totalAscent =>
      (_box.get(_keyTotalAscent) as num?)?.toDouble() ?? 0.0;
  static double get totalDescent =>
      (_box.get(_keyTotalDescent) as num?)?.toDouble() ?? 0.0;
  static int get samplesCount =>
      _box.get(_keySamplesCount, defaultValue: 0) as int;

  /// Process a new altitude reading from the GPS.
  /// [altitudeAccuracy] in metres — skip readings with accuracy > 30m.
  static Future<void> recordAltitude(double altitude,
      {double altitudeAccuracy = 0.0}) async {
    // Skip noisy GPS altitude readings
    if (altitudeAccuracy > 30.0 && altitudeAccuracy != 0.0) return;

    // Update max/min
    if (altitude > maxAltitude || samplesCount == 0) {
      await _box.put(_keyMaxAltitude, altitude);
    }
    if (altitude < minAltitude || samplesCount == 0) {
      await _box.put(_keyMinAltitude, altitude);
    }

    // Compute ascent/descent delta
    if (_lastAltitude != null) {
      final delta = altitude - _lastAltitude!;
      if (delta > 2.0) {
        // >2m gain threshold to filter noise
        await _box.put(_keyTotalAscent, totalAscent + delta);
      } else if (delta < -2.0) {
        await _box.put(_keyTotalDescent, totalDescent + delta.abs());
      }
    }

    _lastAltitude = altitude;
    await _box.put(_keyLastAltitude, altitude);
    await _box.put(_keySamplesCount, samplesCount + 1);
    _updateController.add(null);
  }

  static Future<void> reset() async {
    await _box.deleteAll([
      _keyMaxAltitude,
      _keyMinAltitude,
      _keyTotalAscent,
      _keyTotalDescent,
      _keyLastAltitude,
      _keySamplesCount,
    ]);
    _lastAltitude = null;
  }

  static Map<String, dynamic> toMap() => {
        'maxAltitude': maxAltitude,
        'minAltitude': minAltitude,
        'totalAscent': totalAscent,
        'totalDescent': totalDescent,
        'samplesCount': samplesCount,
      };
}
