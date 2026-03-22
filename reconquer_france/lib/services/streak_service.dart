import 'package:hive_flutter/hive_flutter.dart';

/// Tracks daily exploration streaks using Hive local storage.
class StreakService {
  static late Box _box;

  static const _keyCurrentStreak = 'currentStreak';
  static const _keyLongestStreak = 'longestStreak';
  static const _keyLastActiveDate = 'lastActiveDate';
  static const _keyTotalDaysActive = 'totalDaysActive';
  static const _keyStreakHistory = 'streakHistory'; // List of active date strings

  static Future<void> init() async {
    _box = await Hive.openBox('streak_data');
  }

  static int get currentStreak => _box.get(_keyCurrentStreak, defaultValue: 0) as int;
  static int get longestStreak => _box.get(_keyLongestStreak, defaultValue: 0) as int;
  static int get totalDaysActive => _box.get(_keyTotalDaysActive, defaultValue: 0) as int;

  static String? get lastActiveDateStr =>
      _box.get(_keyLastActiveDate) as String?;

  static DateTime? get lastActiveDate {
    final s = lastActiveDateStr;
    if (s == null) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  /// Returns all historic active dates as a Set<String> in 'YYYY-MM-DD' format.
  static Set<String> get activeDates {
    final raw = _box.get(_keyStreakHistory);
    if (raw == null) return {};
    return (raw as List).cast<String>().toSet();
  }

  /// Called whenever a new cell is unlocked. Updates streak accordingly.
  static Future<void> recordActivity() async {
    final today = _todayStr();
    final last = lastActiveDateStr;

    // Already recorded today
    if (last == today) return;

    final dates = activeDates;
    dates.add(today);
    await _box.put(_keyStreakHistory, dates.toList());
    await _box.put(_keyTotalDaysActive, dates.length);
    await _box.put(_keyLastActiveDate, today);

    // Compute streak
    if (last == null) {
      await _box.put(_keyCurrentStreak, 1);
    } else {
      final lastDate = DateTime.parse(last);
      final todayDate = DateTime.parse(today);
      final diff = todayDate.difference(lastDate).inDays;
      if (diff == 1) {
        // Consecutive day
        final newStreak = currentStreak + 1;
        await _box.put(_keyCurrentStreak, newStreak);
        if (newStreak > longestStreak) {
          await _box.put(_keyLongestStreak, newStreak);
        }
      } else if (diff > 1) {
        // Streak broken
        await _box.put(_keyCurrentStreak, 1);
      }
      // diff == 0 handled above (already recorded today)
    }

    // Ensure longest streak is always up to date
    if (currentStreak > longestStreak) {
      await _box.put(_keyLongestStreak, currentStreak);
    }
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns a list of (weekday 0=Mon, active) for the past 7 days — for mini calendar display.
  static List<({String date, bool active})> lastSevenDays() {
    final dates = activeDates;
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final s = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return (date: s, active: dates.contains(s));
    });
  }
}
