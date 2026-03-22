import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/sync_service.dart';
import '../services/location_service.dart';
import '../core/constants.dart';
import 'auth_provider.dart';

/// Current trip ID
final currentTripIdProvider = StateProvider<String?>((ref) => null);

/// All locally unlocked cells (reactive)
final unlockedCellsProvider =
    StateNotifierProvider<CellsNotifier, Set<String>>((ref) {
  return CellsNotifier(ref);
});

class CellsNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;
  StreamSubscription<String>? _sub;

  CellsNotifier(this._ref) : super(SyncService.getLocalUnlockedCells()) {
    // Listen for new cells unlocked by background GPS
    _sub = LocationService.onCellUnlocked.listen((hexId) {
      state = {...state, hexId};
    });
  }

  void unlockCell(String hexId) {
    if (state.contains(hexId)) return;
    state = {...state, hexId};
    final tripId = _ref.read(currentTripIdProvider);
    if (tripId != null) {
      SyncService.unlockCell(hexId, tripId);
    }
  }

  void loadFromLocal() {
    state = SyncService.getLocalUnlockedCells();
  }

  double get percentFrance => (state.length / TOTAL_FRANCE_HEXES) * 100;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Friends' unlocked cells — stream from Firestore
final friendsCellsProvider =
    StreamProvider<Map<String, Set<String>>>((ref) async* {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    yield {};
    return;
  }

  final firestore = FirebaseFirestore.instance;

  // Get user's friend list
  final userDoc = await firestore.collection('users').doc(user.uid).get();
  final friendIds = List<String>.from(
      userDoc.data()?['friendIds'] as List? ?? []);

  if (friendIds.isEmpty) {
    yield {};
    return;
  }

  // Listen to friend trip documents
  final Map<String, Set<String>> friendCells = {};

  final controllers = <StreamSubscription>[];

  for (final friendId in friendIds.take(8)) {
    // Limit to 8 friends for perf
    final sub = firestore
        .collection('users')
        .doc(friendId)
        .collection('trips')
        .orderBy('startDate', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final cells = List<String>.from(
            snapshot.docs.first.data()['unlockedCells'] as List? ?? []);
        friendCells[friendId] = cells.toSet();
      }
    });
    controllers.add(sub);
  }

  // Yield periodically as updates come
  await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
    yield Map<String, Set<String>>.from(friendCells);
  }
});

/// Group members' cells for the current trip group
final groupCellsProvider =
    StreamProvider<Map<String, Set<String>>>((ref) async* {
  final tripId = ref.watch(currentTripIdProvider);
  final user = ref.watch(authStateProvider).value;

  if (tripId == null || user == null) {
    yield {};
    return;
  }

  final firestore = FirebaseFirestore.instance;

  // Get the trip to find group
  final tripDoc = await firestore
      .collection('users')
      .doc(user.uid)
      .collection('trips')
      .doc(tripId)
      .get();

  final groupId = tripDoc.data()?['groupId'] as String?;
  if (groupId == null) {
    yield {};
    return;
  }

  // Get group members
  final groupDoc =
      await firestore.collection('groups').doc(groupId).get();
  final memberIds = List<String>.from(
      groupDoc.data()?['memberIds'] as List? ?? []);

  final Map<String, Set<String>> memberCells = {};

  // Stream each member's cells
  yield* firestore
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .asyncExpand((_) async* {
    for (final memberId in memberIds) {
      if (memberId == user.uid) continue;
      try {
        final trips = await firestore
            .collection('users')
            .doc(memberId)
            .collection('trips')
            .orderBy('startDate', descending: true)
            .limit(1)
            .get();

        if (trips.docs.isNotEmpty) {
          final cells = List<String>.from(
              trips.docs.first.data()['unlockedCells'] as List? ?? []);
          memberCells[memberId] = cells.toSet();
        }
      } catch (_) {}
    }
    yield Map<String, Set<String>>.from(memberCells);
  });
});

/// Viewport bounds state for hex culling
class ViewportBounds {
  final double northLat;
  final double southLat;
  final double westLng;
  final double eastLng;

  const ViewportBounds({
    required this.northLat,
    required this.southLat,
    required this.westLng,
    required this.eastLng,
  });
}

final viewportBoundsProvider = StateProvider<ViewportBounds?>((ref) => null);
