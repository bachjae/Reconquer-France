import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();
  final _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);

      // Create profile fire-and-forget — don't block or fail auth
      _ensureUserProfile(userCred.user!).catchError((_) {});

      return userCred;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with email/password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  /// Register with email/password
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String username,
    required String avatarEmoji,
  }) async {
    // Create auth account first so Firestore rules pass (requires authentication)
    final userCred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);

    try {
      await userCred.user!.updateDisplayName(displayName);

      // Now authenticated — check if username is taken
      final usernameCheck = await _firestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();

      if (usernameCheck.exists) {
        await userCred.user!.delete();
        throw Exception('Username already taken');
      }

      final profile = UserProfile(
        uid: userCred.user!.uid,
        displayName: displayName,
        username: username.toLowerCase(),
        avatarEmoji: avatarEmoji,
        createdAt: DateTime.now(),
        friendIds: [],
      );

      final batch = _firestore.batch();
      batch.set(
        _firestore.collection('users').doc(userCred.user!.uid),
        profile.toFirestore(),
      );
      batch.set(
        _firestore.collection('usernames').doc(username.toLowerCase()),
        {'uid': userCred.user!.uid},
      );
      await batch.commit();

      return userCred;
    } catch (e) {
      // Clean up orphaned auth account if profile creation fails
      if (e.toString() != 'Exception: Username already taken') {
        await userCred.user?.delete();
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> _ensureUserProfile(User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      final username = _generateUsername(user.displayName ?? user.email ?? 'user');
      final profile = UserProfile(
        uid: user.uid,
        displayName: user.displayName ?? 'Traveler',
        username: username,
        avatarEmoji: '🌽',
        createdAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(
            profile.toFirestore(),
            SetOptions(merge: true),
          );
    }
  }

  String _generateUsername(String base) {
    final cleaned = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final short = cleaned.length > 12 ? cleaned.substring(0, 12) : cleaned;
    return '${short}_${DateTime.now().millisecondsSinceEpoch % 9999}';
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateFcmToken(String token) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (_) {
      // Non-fatal — next refresh will retry
    }
  }
}
