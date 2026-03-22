import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../models/trip_group.dart';
import '../../providers/social_provider.dart';

class GroupScreen extends ConsumerWidget {
  final String groupId;

  const GroupScreen({required this.groupId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(groupLeaderboardProvider(groupId));
    final alerts = ref.watch(groupAlertsProvider(groupId));

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      appBar: AppBar(
        title: Text(
          'Group',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .snapshots(),
        builder: (context, snapshot) {
          TripGroup? group;
          if (snapshot.hasData && snapshot.data!.exists) {
            group = TripGroup.fromFirestore(
                snapshot.data! as DocumentSnapshot<Map<String, dynamic>>);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Group header
              if (group != null) _GroupHeader(group: group),
              const SizedBox(height: 16),

              // Recent alerts
              Text('Recent Alerts',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              alerts.when(
                data: (alertList) {
                  if (alertList.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No recent alerts. Everyone is safe! 🎉',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                  return Column(
                    children: alertList
                        .map((a) => _AlertCard(alert: a, groupId: groupId))
                        .toList(),
                  );
                },
                loading: () =>
                    const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),

              // Leaderboard
              Text('Leaderboard',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              leaderboard.when(
                data: (entries) => Column(
                  children: entries
                      .asMap()
                      .entries
                      .map((e) => _LeaderboardRow(
                            entry: e.value,
                            rank: e.key + 1,
                          ))
                      .toList(),
                ),
                loading: () =>
                    const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final TripGroup group;

  const _GroupHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('👥', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${group.memberIds.length} members',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            // Share invite code
            OutlinedButton.icon(
              onPressed: () => Share.share(
                'Join my France trip group!\nInvite code: ${group.inviteCode}\n'
                'Download Reconquer France app to join!',
              ),
              icon: const Icon(Icons.share),
              label: Text('Share Code: ${group.inviteCode}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  final GroupAlert alert;
  final String groupId;

  const _AlertCard({required this.alert, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHusker = alert.type == AlertType.husker;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHusker
            ? const Color(kColorHusker).withOpacity(0.1)
            : const Color(kColorCorn).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHusker
              ? const Color(kColorHusker).withOpacity(0.5)
              : const Color(kColorCorn).withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Text(isHusker ? '🚨' : '🌽',
              style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.senderName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  alert.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${alert.lat.toStringAsFixed(4)}, ${alert.lng.toStringAsFixed(4)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(kColorAccent)),
                ),
              ],
            ),
          ),
          if (!alert.isResolved)
            TextButton(
              onPressed: () {},
              child: Text(
                "I'm coming",
                style: TextStyle(
                    color: isHusker
                        ? const Color(kColorHusker)
                        : const Color(kColorCorn)),
              ),
            ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;

  const _LeaderboardRow({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(rank == 1 ? '👑' : '#$rank'),
      title: Text('${entry.avatarEmoji} ${entry.displayName}'),
      subtitle: Text('@${entry.username}'),
      trailing: Text(
        '${entry.cellsUnlocked} cells',
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: const Color(kColorAccent)),
      ),
    );
  }
}
