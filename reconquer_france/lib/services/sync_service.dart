import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/constants.dart';

class SyncService {
  static late Box<String> _cellsBox;
  static late Box _syncQueue;
  static late Box _photosBox;
  static Timer? _debounceTimer;
  static StreamSubscription? _connectivitySub;

  static Future<void> init() async {
    await Hive.initFlutter();
    _cellsBox = await Hive.openBox<String>('unlocked_cells');
    _syncQueue = await Hive.openBox('sync_queue');
    _photosBox = await Hive.openBox('trip_photos');

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
          final tripId = entry['tripId'] as String;
          byTrip.putIfAbsent(tripId, () => []);
          byTrip[tripId]!.add(entry['hexId'] as String);
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
            tripDoc.data()?['totalCellsUnlocked'] as int? ?? 0;

        if (currentCount >= kMaxUnlockedCellsPerDoc) {
          // Use subcollection chunks
          final chunkIndex = currentCount ~/ kMaxUnlockedCellsPerDoc;
          final chunkRef = ref
              .collection('cell_chunks')
              .doc('chunk_$chunkIndex');
          batch.set(
            chunkRef,
            {'cells': FieldValue.arrayUnion(hexIds)},
            SetOptions(merge: true),
          );
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
    }
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
