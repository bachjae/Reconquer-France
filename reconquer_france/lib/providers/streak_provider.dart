import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/streak_service.dart';

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
  StreakNotifier()
      : super(StreakState(
          currentStreak: StreakService.currentStreak,
          longestStreak: StreakService.longestStreak,
          totalDaysActive: StreakService.totalDaysActive,
          lastSevenDays: StreakService.lastSevenDays(),
        ));

  void refresh() {
    state = StreakState(
      currentStreak: StreakService.currentStreak,
      longestStreak: StreakService.longestStreak,
      totalDaysActive: StreakService.totalDaysActive,
      lastSevenDays: StreakService.lastSevenDays(),
    );
  }
}

final streakProvider =
    StateNotifierProvider<StreakNotifier, StreakState>((ref) {
  return StreakNotifier();
});
