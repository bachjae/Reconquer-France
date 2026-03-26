import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../providers/map_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/hex_grid_service.dart';

/// Shows a canvas-based conquest map merging cells from all group members.
class CollaborativeMapScreen extends ConsumerWidget {
  const CollaborativeMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myCells = ref.watch(unlockedCellsProvider);
    final groupCells = ref.watch(groupCellsProvider);
    final profile = ref.watch(refreshableProfileProvider);
    final myUid = profile.value?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      appBar: AppBar(
        backgroundColor: const Color(kColorBackground),
        title: Text(
          'Conquest Map',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontFamily: 'PlayfairDisplay'),
        ),
      ),
      body: groupCells.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildMap(context, myCells, {}, myUid),
        data: (memberCells) =>
            _buildMap(context, myCells, memberCells, myUid),
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    Set<String> myCells,
    Map<String, Set<String>> memberCells,
    String myUid,
  ) {
    // Build a color map: uid → color index
    final members = [myUid, ...memberCells.keys.where((k) => k != myUid)];
    final colorMap = <String, int>{};
    for (int i = 0; i < members.length; i++) {
      colorMap[members[i]] = i % kGroupMemberColors.length;
    }

    // Build all-cells map: hexId → ownerUid (first claimer wins)
    final Map<String, String> allCells = {};
    for (final hexId in myCells) {
      allCells[hexId] = myUid;
    }
    for (final entry in memberCells.entries) {
      for (final hexId in entry.value) {
        allCells.putIfAbsent(hexId, () => entry.key);
      }
    }

    // Compute totals
    final myCount = myCells.length;
    final totalCells = allCells.length;
    final memberCounts = <String, int>{
      for (final uid in members)
        uid: uid == myUid
            ? myCount
            : (memberCells[uid]?.length ?? 0),
    };

    return Column(
      children: [
        // Stats header
        _StatsHeader(
          members: members,
          counts: memberCounts,
          colorMap: colorMap,
          myUid: myUid,
          totalCells: totalCells,
        ),

        // Map canvas
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _CollaborativePainter(
                allCells: allCells,
                colorMap: colorMap,
              ),
            );
          }),
        ),

        // Bottom note
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF0F0F1A),
          child: Text(
            'Combined conquest: ${(totalCells / TOTAL_FRANCE_HEXES * 100).toStringAsFixed(2)}% of France',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(kColorAccent),
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final List<String> members;
  final Map<String, int> counts;
  final Map<String, int> colorMap;
  final String myUid;
  final int totalCells;

  const _StatsHeader({
    required this.members,
    required this.counts,
    required this.colorMap,
    required this.myUid,
    required this.totalCells,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF0F0F1A),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Group Members',
                  style: Theme.of(context).textTheme.titleSmall),
              Text(
                '$totalCells total cells',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: members.map((uid) {
                final colorIdx = colorMap[uid] ?? 0;
                final color = Color(kGroupMemberColors[colorIdx] | 0xFF000000);
                final count = counts[uid] ?? 0;
                final isMe = uid == myUid;

                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isMe ? 'You' : uid.substring(0, 6),
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollaborativePainter extends CustomPainter {
  final Map<String, String> allCells; // hexId → ownerUid
  final Map<String, int> colorMap; // uid → color index

  _CollaborativePainter({required this.allCells, required this.colorMap});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(kColorBackground);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // France border
    final borderPaint = Paint()
      ..color = const Color(kColorAccent).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(
      Rect.fromLTWH(
          size.width * 0.05,
          size.height * 0.05,
          size.width * 0.90,
          size.height * 0.90),
      borderPaint,
    );

    // Draw each cell as a small dot
    for (final entry in allCells.entries) {
      final hexId = entry.key;
      final ownerUid = entry.value;
      final colorIdx = colorMap[ownerUid] ?? 0;
      final rawColor = kGroupMemberColors[colorIdx % kGroupMemberColors.length];
      final color = Color(rawColor | 0xFF000000).withValues(alpha: 0.75);

      final center = HexGridService.hexIdToCenter(hexId);
      final p = _latLngToOffset(center.latitude, center.longitude, size);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(p, 1.8, paint);
    }
  }

  Offset _latLngToOffset(double lat, double lng, Size size) {
    const padding = 0.06;
    final x = (padding +
            (lng - FRANCE_WEST) / (FRANCE_EAST - FRANCE_WEST) * (1 - 2 * padding)) *
        size.width;
    final y = (padding +
            (1 - (lat - FRANCE_SOUTH) / (FRANCE_NORTH - FRANCE_SOUTH)) *
                (1 - 2 * padding)) *
        size.height;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(_CollaborativePainter old) =>
      old.allCells.length != allCells.length;
}
