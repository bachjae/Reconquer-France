import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:reconquer_france/services/streak_service.dart';

/// Format a DateTime to 'YYYY-MM-DD'.
String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_streak_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    // Delete any leftover box and open fresh
    if (Hive.isBoxOpen('streak_data')) {
      await Hive.box('streak_data').deleteFromDisk();
    }
    await StreakService.init();
  });

  tearDown(() async {
    if (Hive.isBoxOpen('streak_data')) {
      await Hive.box('streak_data').close();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // ── Initial state ─────────────────────────────────────────────────────────

  test('initial streak values are 0 before any activity', () {
    expect(StreakService.currentStreak, equals(0));
    expect(StreakService.longestStreak, equals(0));
    expect(StreakService.totalDaysActive, equals(0));
  });

  test('lastActiveDate is null before any activity', () {
    expect(StreakService.lastActiveDate, isNull);
  });

  test('activeDates is empty before any activity', () {
    expect(StreakService.activeDates, isEmpty);
  });

  // ── recordActivity ────────────────────────────────────────────────────────

  test('first recordActivity sets streak to 1', () async {
    await StreakService.recordActivity();
    expect(StreakService.currentStreak, equals(1));
    expect(StreakService.totalDaysActive, equals(1));
  });

  test('recordActivity twice on same day does not increment streak', () async {
    await StreakService.recordActivity();
    await StreakService.recordActivity();
    expect(StreakService.currentStreak, equals(1));
    expect(StreakService.totalDaysActive, equals(1));
  });

  test('activeDates contains today after recordActivity', () async {
    await StreakService.recordActivity();
    final today = _fmtDate(DateTime.now());
    expect(StreakService.activeDates, contains(today));
  });

  test('lastActiveDateStr equals today after recordActivity', () async {
    await StreakService.recordActivity();
    final today = _fmtDate(DateTime.now());
    expect(StreakService.lastActiveDateStr, equals(today));
  });

  test('longestStreak updates after first activity', () async {
    await StreakService.recordActivity();
    expect(StreakService.longestStreak, equals(1));
  });

  // ── lastSevenDays ─────────────────────────────────────────────────────────

  test('lastSevenDays returns exactly 7 entries', () {
    final days = StreakService.lastSevenDays();
    expect(days.length, equals(7));
  });

  test('lastSevenDays dates are in ascending order', () {
    final days = StreakService.lastSevenDays();
    for (int i = 1; i < days.length; i++) {
      final prev = DateTime.parse(days[i - 1].date);
      final curr = DateTime.parse(days[i].date);
      expect(curr.isAfter(prev), isTrue,
          reason: 'Dates should be ascending; got ${days[i - 1].date} then ${days[i].date}');
    }
  });

  test('lastSevenDays last entry is today', () {
    final days = StreakService.lastSevenDays();
    final today = _fmtDate(DateTime.now());
    expect(days.last.date, equals(today));
  });

  test('today is active in lastSevenDays after recordActivity', () async {
    await StreakService.recordActivity();
    final days = StreakService.lastSevenDays();
    final today = _fmtDate(DateTime.now());
    final todayEntry = days.firstWhere(
      (d) => d.date == today,
      orElse: () => throw StateError('Today not in lastSevenDays'),
    );
    expect(todayEntry.active, isTrue);
  });

  test('days without activity show as inactive in lastSevenDays', () {
    // No recordActivity called — all days should be inactive
    final days = StreakService.lastSevenDays();
    expect(days.every((d) => !d.active), isTrue);
  });
}
