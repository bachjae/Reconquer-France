import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream of Firebase auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Current user's Firestore profile
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.read(authServiceProvider).getUserProfile(user.uid);
});

/// Refreshable profile provider
final refreshableProfileProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfile?>>(
  (ref) => ProfileNotifier(ref.read(authServiceProvider)),
);

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthService _authService;

  ProfileNotifier(this._authService) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final profile = await _authService.getUserProfile(uid);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();
}
