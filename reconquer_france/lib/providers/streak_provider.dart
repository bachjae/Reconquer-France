import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/streak_service.dart';
import '../services/location_service.dart';

class StreakState {
  final int currentStreak;
  final int longestStreak;
  final int totalDaysActive;
  final List<({String date, bool active})> lastSevenDays;

  const StreakState({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDaysActive,
    required this.lastSevenDays,
  });
}

class StreakNotifier extends StateNotifier<StreakState> {
  StreamSubscription<String>? _cellUnlockSub;

  StreakNotifier()
      : super(StreakState(
          currentStreak: StreakService.currentStreak,
          longestStreak: StreakService.longestStreak,
          totalDaysActive: StreakService.totalDaysActive,
          lastSevenDays: StreakService.lastSevenDays(),
        )) {
    // Refresh streak display whenever a new cell is unlocked so the
    // streak badge updates in real time without requiring an app restart.
    _cellUnlockSub = LocationService.onCellUnlocked.listen((_) => refresh());
  }

  void refresh() {
    state = StreakState(
      currentStreak: StreakService.currentStreak,
      longestStreak: StreakService.longestStreak,
      totalDaysActive: StreakService.totalDaysActive,
      lastSevenDays: StreakService.lastSevenDays(),
    );
  }

  @override
  void dispose() {
    _cellUnlockSub?.cancel();
    super.dispose();
  }
}

final streakProvider =
    StateNotifierProvider<StreakNotifier, StreakState>((ref) {
  return StreakNotifier();
});
