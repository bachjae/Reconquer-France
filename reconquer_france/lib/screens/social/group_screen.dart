import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants.dart';
import '../../models/trip_group.dart';
import '../../providers/social_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class GroupScreen extends ConsumerWidget {
  final String groupId;

  const GroupScreen({required this.groupId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;
    final leaderboard = ref.watch(groupLeaderboardProvider(groupId));
    final alerts = ref.watch(myGroupAlertsProvider);

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
            group = TripGroup.fromFirestore(snapshot.data!);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Group header
              if (group != null) _GroupHeader(group: group),
              const SizedBox(height: 16),

              // Recent alerts (filtered by role)
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
                loading: () => const CircularProgressIndicator(),
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
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),

              // Role management (only visible to group creator)
              if (group != null &&
                  currentUser != null &&
                  group.createdBy == currentUser.uid)
                _RoleManagementSection(group: group),
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
            const SizedBox(height: 8),
            Text(
              '${group.memberIds.length} members · ${group.leaderIds.length} leader(s)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
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
              onPressed: () =>
                  NotificationService.resolveAlert(groupId, alert.id),
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
    final roleLabel = entry.role == GroupMemberRole.leader ? ' 👑' : '';

    return ListTile(
      leading: Text(rank == 1 ? '👑' : '#$rank'),
      title: Text('${entry.avatarEmoji} ${entry.displayName}$roleLabel'),
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

/// Role management panel — only shown to the group creator.
class _RoleManagementSection extends ConsumerWidget {
  final TripGroup group;

  const _RoleManagementSection({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manage Roles',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Assign leaders who will receive corn & husker alerts.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 8),
        ...group.memberIds.map((uid) {
          final role = group.roleOf(uid);
          final isCreator = uid == group.createdBy;

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: role == GroupMemberRole.leader
                  ? const Color(kColorCorn).withOpacity(0.2)
                  : Colors.white10,
              child: Text(
                role == GroupMemberRole.leader ? '👑' : '👤',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            title: Text(
              isCreator ? '$uid (you)' : uid,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              isCreator
                  ? 'Creator · Leader'
                  : role == GroupMemberRole.leader
                      ? 'Leader'
                      : 'Student',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: isCreator
                ? null // Creator role is fixed
                : TextButton(
                    onPressed: () => SocialActions.assignRole(
                      groupId: group.id,
                      createdBy: group.createdBy,
                      targetUid: uid,
                      role: role == GroupMemberRole.leader
                          ? GroupMemberRole.student
                          : GroupMemberRole.leader,
                    ),
                    child: Text(
                      role == GroupMemberRole.leader
                          ? 'Demote'
                          : 'Make Leader',
                      style: TextStyle(
                        color: role == GroupMemberRole.leader
                            ? Colors.white54
                            : const Color(kColorCorn),
                      ),
                    ),
                  ),
          );
        }),
      ],
    );
  }
}
