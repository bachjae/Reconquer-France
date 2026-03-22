import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../providers/social_provider.dart';
import '../../models/trip_group.dart';

class LeaderboardTab extends ConsumerWidget {
  final TripGroup? group;

  const LeaderboardTab({this.group, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (group == null) {
      return const _NoGroupView();
    }

    final leaderboard = ref.watch(groupLeaderboardProvider(group!.id));

    return leaderboard.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Text('No members yet'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            return _LeaderboardEntry(
              entry: entries[i],
              rank: i + 1,
            );
          },
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(kColorAccent))),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _NoGroupView extends StatelessWidget {
  const _NoGroupView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No Group Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create or join a trip group\nto see the leaderboard.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _LeaderboardEntry extends ConsumerWidget {
  final LeaderboardEntry entry;
  final int rank;

  const _LeaderboardEntry({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFirst = rank == 1;
    final color = rank <= kGroupMemberColors.length
        ? Color(kGroupMemberColors[rank - 1])
        : const Color(0xFF2A2A4E);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFirst
              ? const Color(kColorAccent)
              : const Color(0xFF2A2A4E),
          width: isFirst ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rank
            SizedBox(
              width: 28,
              child: Text(
                isFirst ? '👑' : '#$rank',
                style: TextStyle(
                  fontSize: isFirst ? 20 : 14,
                  color: isFirst
                      ? const Color(kColorAccent)
                      : Colors.white54,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: Text(entry.avatarEmoji,
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
        title: Text(
          entry.displayName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isFirst ? const Color(kColorAccent) : Colors.white,
              ),
        ),
        subtitle: Text(
          '@${entry.username}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.cellsUnlocked} cells',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isFirst ? const Color(kColorAccent) : Colors.white70,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              '${entry.percentFrance.toStringAsFixed(2)}% 🇫🇷',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // Mini progress bar
            const SizedBox(height: 4),
            SizedBox(
              width: 80,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (entry.percentFrance / 100).clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFF2A2A4E),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
