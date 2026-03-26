import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    StreamProvider<Map<String, Set<String>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value({});

  final firestore = FirebaseFirestore.instance;
  final Map<String, Set<String>> friendCells = {};
  final controller = StreamController<Map<String, Set<String>>>();
  final subs = <StreamSubscription>[];

  // Load friend list then subscribe to each friend's latest trip
  firestore.collection('users').doc(user.uid).get().then((userDoc) {
    final friendIds = List<String>.from(
        (userDoc.data()?['friendIds'] as List?) ?? []);

    if (friendIds.isEmpty) {
      controller.add({});
      return;
    }

    for (final friendId in friendIds.take(8)) {
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
        } else {
          friendCells.remove(friendId);
        }
        if (!controller.isClosed) {
          controller.add(Map<String, Set<String>>.from(friendCells));
        }
      }, onError: (_) {});
      subs.add(sub);
    }
  }).catchError((_) {
    controller.add({});
  });

  // Cancel all subscriptions when provider is disposed
  ref.onDispose(() {
    for (final sub in subs) {
      sub.cancel();
    }
    controller.close();
  });

  return controller.stream;
});

/// Group members' cells for the current trip group
final groupCellsProvider =
    StreamProvider<Map<String, Set<String>>>((ref) {
  final tripId = ref.watch(currentTripIdProvider);
  final user = ref.watch(authStateProvider).value;

  if (tripId == null || user == null) return Stream.value({});

  final firestore = FirebaseFirestore.instance;
  final Map<String, Set<String>> memberCells = {};
  final controller = StreamController<Map<String, Set<String>>>();
  final subs = <StreamSubscription>[];

  // Bootstrap: load trip → group → member ids, then subscribe
  () async {
    try {
      final tripDoc = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('trips')
          .doc(tripId)
          .get();

      final groupId = tripDoc.data()?['groupId'] as String?;
      if (groupId == null) {
        controller.add({});
        return;
      }

      final groupDoc = await firestore.collection('groups').doc(groupId).get();
      final memberIds = List<String>.from(
          groupDoc.data()?['memberIds'] as List? ?? []);

      for (final memberId in memberIds) {
        if (memberId == user.uid) continue;

        final sub = firestore
            .collection('users')
            .doc(memberId)
            .collection('trips')
            .orderBy('startDate', descending: true)
            .limit(1)
            .snapshots()
            .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final cells = List<String>.from(
                snapshot.docs.first.data()['unlockedCells'] as List? ?? []);
            memberCells[memberId] = cells.toSet();
          } else {
            memberCells.remove(memberId);
          }
          if (!controller.isClosed) {
            controller.add(Map<String, Set<String>>.from(memberCells));
          }
        }, onError: (_) {});
        subs.add(sub);
      }
    } catch (_) {
      if (!controller.isClosed) controller.add({});
    }
  }();

  ref.onDispose(() {
    for (final sub in subs) {
      sub.cancel();
    }
    controller.close();
  });

  return controller.stream;
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
