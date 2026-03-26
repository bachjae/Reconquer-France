import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/elevation_service.dart';

class ElevationStats {
  final double maxAltitude;
  final double minAltitude;
  final double totalAscent;
  final double totalDescent;
  final int samplesCount;

  const ElevationStats({
    required this.maxAltitude,
    required this.minAltitude,
    required this.totalAscent,
    required this.totalDescent,
    required this.samplesCount,
  });

  factory ElevationStats.fromService() => ElevationStats(
        maxAltitude: ElevationService.maxAltitude,
        minAltitude: ElevationService.minAltitude,
        totalAscent: ElevationService.totalAscent,
        totalDescent: ElevationService.totalDescent,
        samplesCount: ElevationService.samplesCount,
      );

  static const empty = ElevationStats(
    maxAltitude: 0,
    minAltitude: 0,
    totalAscent: 0,
    totalDescent: 0,
    samplesCount: 0,
  );
}

class ElevationNotifier extends StateNotifier<ElevationStats> {
  StreamSubscription<void>? _sub;

  ElevationNotifier() : super(ElevationStats.fromService()) {
    _sub = ElevationService.onUpdate.listen((_) {
      state = ElevationStats.fromService();
    });
  }

  void refresh() {
    state = ElevationStats.fromService();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final elevationProvider =
    StateNotifierProvider<ElevationNotifier, ElevationStats>((ref) {
  return ElevationNotifier();
});
