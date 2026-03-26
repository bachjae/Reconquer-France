import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';

final testModeProvider =
    StateNotifierProvider<TestModeNotifier, bool>((ref) => TestModeNotifier());

class TestModeNotifier extends StateNotifier<bool> {
  TestModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('test_mode_lincoln') ?? false;
    // Keep LocationService in sync immediately so GPS uses correct mode
    LocationService.testMode = state;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    state = !state;
    LocationService.testMode = state;
    await prefs.setBool('test_mode_lincoln', state);
    // Re-check the last known position with the new test mode
    LocationService.recheckLastPosition();
  }
}
