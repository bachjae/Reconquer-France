import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip_group.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

final _firestore = FirebaseFirestore.instance;

/// Current user's active group
final activeGroupProvider = StreamProvider<TripGroup?>((ref) async* {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    yield null;
    return;
  }

  yield* _firestore
      .collection('groups')
      .where('memberIds', arrayContains: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((snap) {
    if (snap.docs.isEmpty) return null;
    return TripGroup.fromFirestore(snap.docs.first);
  });
});

/// Group leaderboard (sorted by cells unlocked)
final groupLeaderboardProvider =
    StreamProvider.family<List<LeaderboardEntry>, String>((ref, groupId) {
  return _firestore
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .asyncMap((groupSnap) async {
    final group = TripGroup.fromFirestore(groupSnap);

    final entries = <LeaderboardEntry>[];

    for (final uid in group.memberIds) {
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final trips = await _firestore
            .collection('users')
            .doc(uid)
            .collection('trips')
            .orderBy('startDate', descending: true)
            .limit(1)
            .get();

        final profile = UserProfile.fromFirestore(userDoc);
        final totalCells = trips.docs.isNotEmpty
            ? trips.docs.first.data()['totalCellsUnlocked'] as int? ?? 0
            : 0;

        entries.add(LeaderboardEntry(
          uid: uid,
          displayName: profile.displayName,
          username: profile.username,
          avatarEmoji: profile.avatarEmoji,
          cellsUnlocked: totalCells,
          percentFrance: totalCells / 550000 * 100,
          role: group.roleOf(uid),
        ));
      } catch (_) {}
    }

    entries.sort((a, b) => b.cellsUnlocked.compareTo(a.cellsUnlocked));
    return entries;
  });
});

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String username;
  final String avatarEmoji;
  final int cellsUnlocked;
  final double percentFrance;
  final GroupMemberRole role;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.avatarEmoji,
    required this.cellsUnlocked,
    required this.percentFrance,
    required this.role,
  });
}

/// Friend requests for current user
final pendingFriendRequestsProvider =
    StreamProvider<List<FriendRequest>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  return _firestore
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .asyncExpand((userDoc) {
    final username = userDoc.data()?['username'] as String? ?? '';
    if (username.isEmpty) return const Stream.empty();

    return _firestore
        .collection('friendRequests')
        .where('toUsername', isEqualTo: username)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendRequest.fromFirestore(d))
            .toList());
  });
});

/// All unresolved alerts for the current user's group.
/// Leaders see every alert; students only see alerts with recipientType == 'all'.
final myGroupAlertsProvider = StreamProvider<List<GroupAlert>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final group = ref.watch(activeGroupProvider).value;
  if (user == null || group == null) return const Stream.empty();

  final isLeader = group.roleOf(user.uid) == GroupMemberRole.leader;

  return _firestore
      .collection('groups')
      .doc(group.id)
      .collection('alerts')
      .where('resolvedAt', isEqualTo: null)
      .orderBy('timestamp', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) {
    final all =
        snap.docs.map((d) => GroupAlert.fromFirestore(d)).toList();
    if (isLeader) return all;
    // Students only see alerts not targeted exclusively at leaders
    return all.where((a) => a.recipientType == 'all').toList();
  });
});

/// Raw alerts stream (family — used by GroupScreen which receives groupId)
final groupAlertsProvider =
    StreamProvider.family<List<GroupAlert>, String>((ref, groupId) {
  return _firestore
      .collection('groups')
      .doc(groupId)
      .collection('alerts')
      .where('resolvedAt', isEqualTo: null)
      .orderBy('timestamp', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => GroupAlert.fromFirestore(d))
          .toList());
});

/// Social actions
class SocialActions {
  static Future<void> sendFriendRequest(String toUsername) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('friendRequests').add({
      'fromUid': uid,
      'toUsername': toUsername.toLowerCase(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> acceptFriendRequest(FriendRequest request) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final batch = _firestore.batch();

    batch.update(
      _firestore.collection('friendRequests').doc(request.id),
      {'status': 'accepted'},
    );

    batch.update(
      _firestore.collection('users').doc(uid),
      {'friendIds': FieldValue.arrayUnion([request.fromUid])},
    );

    batch.update(
      _firestore.collection('users').doc(request.fromUid),
      {'friendIds': FieldValue.arrayUnion([uid])},
    );

    await batch.commit();
  }

  static Future<void> declineFriendRequest(String requestId) async {
    await _firestore
        .collection('friendRequests')
        .doc(requestId)
        .update({'status': 'declined'});
  }

  static Future<TripGroup> createGroup(String name, String tripId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final inviteCode = _generateInviteCode();

    final docRef = await _firestore.collection('groups').add({
      'name': name,
      'createdBy': uid,
      'memberIds': [uid],
      'roles': {uid: 'leader'}, // Creator is always a leader
      'tripId': tripId,
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final doc = await docRef.get();
    return TripGroup.fromFirestore(doc);
  }

  static Future<TripGroup?> joinGroupByCode(String inviteCode) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final query = await _firestore
        .collection('groups')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final groupDoc = query.docs.first;
    await _firestore.collection('groups').doc(groupDoc.id).update({
      'memberIds': FieldValue.arrayUnion([uid]),
      'roles.$uid': 'student', // Joiners start as students
    });

    return TripGroup.fromFirestore(groupDoc);
  }

  /// Assign a role to a group member. Only the group creator can do this.
  static Future<void> assignRole({
    required String groupId,
    required String createdBy,
    required String targetUid,
    required GroupMemberRole role,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != createdBy) return;

    await _firestore.collection('groups').doc(groupId).update({
      'roles.$targetUid': role == GroupMemberRole.leader ? 'leader' : 'student',
    });
  }

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (i) => chars[(random + i * 7) % chars.length])
        .join();
  }
}
