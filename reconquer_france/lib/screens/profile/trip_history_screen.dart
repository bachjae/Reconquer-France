import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/photo_provider.dart';
import '../../services/sync_service.dart';
import '../gallery/trip_collection_screen.dart';

/// Shows every trip the user has ever created, sorted newest first.
/// Tapping a trip opens its photo collection.
class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      appBar: AppBar(
        backgroundColor: const Color(kColorBackground),
        title: const Text('Trip History'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('trips')
                  .orderBy('startDate', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(kColorAccent)),
                  );
                }

                if (snap.hasError) {
                  return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(color: Colors.white54)),
                  );
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🏰',
                            style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text('No trips yet',
                            style:
                                Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your first trip to start\nconquering France.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }

                // Precompute photo counts per tripId from local storage
                final allPhotos = ref.read(allPhotosProvider);
                final photoCountByTrip = <String, int>{};
                for (final p in allPhotos) {
                  final id = p['tripId'] as String? ?? 'local';
                  photoCountByTrip[id] = (photoCountByTrip[id] ?? 0) + 1;
                }

                final localCellCount =
                    SyncService.getLocalUnlockedCells().length;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final tripId = doc.id;

                    final name = data['name'] as String? ?? 'Unnamed Trip';
                    final startTs = data['startDate'] as Timestamp?;
                    final endTs = data['endDate'] as Timestamp?;
                    final startDate = startTs?.toDate();
                    final endDate = endTs?.toDate();
                    final cells =
                        data['totalCellsUnlocked'] as int? ??
                        // Fall back to local count for the active trip
                        (i == 0 ? localCellCount : 0);
                    final percent =
                        (data['percentFrance'] as num?)?.toDouble() ??
                        (cells / TOTAL_FRANCE_HEXES * 100);
                    final photos = photoCountByTrip[tripId] ?? 0;

                    return _TripHistoryCard(
                      tripId: tripId,
                      name: name,
                      startDate: startDate,
                      endDate: endDate,
                      cells: cells,
                      percent: percent,
                      photoCount: photos,
                      isActive: i == 0,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _TripHistoryCard extends StatelessWidget {
  final String tripId;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final int cells;
  final double percent;
  final int photoCount;
  final bool isActive;

  const _TripHistoryCard({
    required this.tripId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.cells,
    required this.percent,
    required this.photoCount,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    String dateStr = startDate != null ? fmt.format(startDate!) : '—';
    if (endDate != null) {
      dateStr += ' – ${fmt.format(endDate!)}';
    } else if (startDate != null) {
      dateStr += isActive ? ' – Present' : '';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TripCollectionScreen(tripId: tripId)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? const Color(kColorAccent).withOpacity(0.5)
                : const Color(0xFF2A2A4E),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + active badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(kColorAccent).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(kColorAccent).withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                          color: Color(kColorAccent),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Date range
            Text(
              dateStr,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: const Color(0xFF2A2A4E),
                color: const Color(kColorUnlockedHex),
              ),
            ),
            const SizedBox(height: 10),
            // Stats row
            Row(
              children: [
                _Chip(
                    icon: Icons.hexagon_outlined,
                    label: '$cells cells'),
                const SizedBox(width: 10),
                _Chip(
                    icon: Icons.public,
                    label: '${percent.toStringAsFixed(2)}%'),
                const SizedBox(width: 10),
                _Chip(
                    icon: Icons.photo_library_outlined,
                    label: '$photoCount photos'),
                const Spacer(),
                const Icon(Icons.chevron_right,
                    color: Colors.white24, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(kColorAccent)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
