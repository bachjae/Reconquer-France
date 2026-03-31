import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/constants.dart';
import 'streak_service.dart';
import 'elevation_service.dart';
import 'notification_service.dart';

class SyncService {
  static late Box<String> _cellsBox;
  static late Box _syncQueue;
  static late Box _photosBox;
  static late Box<String> _timestampsBox; // hexId → ISO8601 unlock time
  static Timer? _debounceTimer;
  static StreamSubscription? _connectivitySub;

  static Future<void> init() async {
    await Hive.initFlutter();
    _cellsBox = await Hive.openBox<String>('unlocked_cells');
    _syncQueue = await Hive.openBox('sync_queue');
    _photosBox = await Hive.openBox('trip_photos');
    _timestampsBox = await Hive.openBox<String>('unlock_timestamps');
    await StreakService.init();
    await ElevationService.init();

    // Listen for connectivity changes and flush queue
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      if (results.isNotEmpty &&
          results.first != ConnectivityResult.none) {
        _flushQueue();
      }
    });
  }

  static Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _debounceTimer?.cancel();
  }

  /// Unlock a cell — save locally, queue for Firestore
  static Future<void> unlockCell(String hexId, String tripId) async {
    // Already unlocked locally — skip
    if (_cellsBox.containsKey(hexId)) return;

    // Save locally first
    await _cellsBox.put(hexId, hexId);

    // Record unlock timestamp
    final ts = DateTime.now().toIso8601String();
    await _timestampsBox.put(hexId, ts);

    // Record streak activity
    await StreakService.recordActivity();

    // Fire milestone notification if applicable (fire-and-forget)
    const milestones = {100, 500, 1000, 5000, 10000};
    final count = _cellsBox.length;
    if (milestones.contains(count)) {
      NotificationService.showMilestone(count);
    }

    // Queue for remote sync
    final queueEntry = {
      'type': 'unlock_cell',
      'hexId': hexId,
      'tripId': tripId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _syncQueue.add(queueEntry);

    // Debounced sync (max once every 30 seconds)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(seconds: kSyncDebounceSeconds),
      () => _flushQueue(),
    );

    // Try immediate sync if online
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isNotEmpty &&
        connectivity.first != ConnectivityResult.none) {
      _debounceTimer?.cancel();
      await _flushQueue();
    }
  }

  static Future<void> _flushQueue() async {
    final entries = _syncQueue.values.toList();
    if (entries.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Group by tripId to batch efficiently
      final Map<String, List<String>> byTrip = {};
      for (final entry in entries) {
        if (entry['type'] == 'unlock_cell') {
          final tripId = entry['tripId'];
          final hexId = entry['hexId'];
          if (tripId is! String || hexId is! String) continue;
          byTrip.putIfAbsent(tripId, () => []);
          byTrip[tripId]!.add(hexId);
        }
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final tripId in byTrip.keys) {
        final hexIds = byTrip[tripId]!;
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('trips')
            .doc(tripId);

        // Check current cell count to handle chunking
        final tripDoc = await ref.get();
        final currentCount =
            (tripDoc.data()?['totalCellsUnlocked'] as num?)?.toInt() ?? 0;

        if (currentCount >= kMaxUnlockedCellsPerDoc) {
          // Use subcollection chunks for the cell list
          final chunkIndex = currentCount ~/ kMaxUnlockedCellsPerDoc;
          final chunkRef = ref
              .collection('cell_chunks')
              .doc('chunk_$chunkIndex');
          batch.set(
            chunkRef,
            {'cells': FieldValue.arrayUnion(hexIds)},
            SetOptions(merge: true),
          );
          // Still update the stats counters on the trip doc
          batch.update(ref, {
            'totalCellsUnlocked': FieldValue.increment(hexIds.length),
            'percentFrance':
                (currentCount + hexIds.length) / TOTAL_FRANCE_HEXES * 100,
          });
        } else {
          batch.update(ref, {
            'unlockedCells': FieldValue.arrayUnion(hexIds),
            'totalCellsUnlocked': FieldValue.increment(hexIds.length),
            'percentFrance':
                (currentCount + hexIds.length) / TOTAL_FRANCE_HEXES * 100,
          });
        }
      }

      await batch.commit();
      await _syncQueue.clear();
    } catch (e) {
      // Keep in queue for retry
      debugPrint('[SyncService] _flushQueue error: $e');
    }
  }

  /// Returns map of hexId → unlock DateTime, sorted by time ascending.
  static Map<String, DateTime> getUnlockTimestamps() {
    final result = <String, DateTime>{};
    for (final key in _timestampsBox.keys) {
      final val = _timestampsBox.get(key);
      if (val != null) {
        try {
          result[key as String] = DateTime.parse(val);
        } catch (_) {}
      }
    }
    return result;
  }

  static Set<String> getLocalUnlockedCells() {
    return _cellsBox.values.toSet();
  }

  static bool isCellUnlocked(String hexId) {
    return _cellsBox.containsKey(hexId);
  }

  static int get localUnlockedCount => _cellsBox.length;

  /// Save photo reference locally
  static Future<void> savePhotoRef(Map<String, dynamic> photoData) async {
    await _photosBox.put(photoData['id'], photoData);
  }

  static List<Map<String, dynamic>> getAllLocalPhotos() {
    return _photosBox.values
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  static List<Map<String, dynamic>> getPhotosForHex(String hexId) {
    return _photosBox.values
        .whereType<Map>()
        .where((m) => m['hexId'] == hexId)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  /// Sync all local cells to Firestore for a trip (initial load)
  static Future<void> syncAllCellsToFirestore(String tripId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final allCells = _cellsBox.values.toList();
    if (allCells.isEmpty) return;

    // Enqueue all cells
    for (final cellId in allCells) {
      await _syncQueue.add({
        'type': 'unlock_cell',
        'hexId': cellId,
        'tripId': tripId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    await _flushQueue();
  }
}
