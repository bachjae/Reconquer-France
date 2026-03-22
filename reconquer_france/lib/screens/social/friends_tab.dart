import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../providers/social_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip_group.dart';

class FriendsTab extends ConsumerStatefulWidget {
  const FriendsTab({super.key});

  @override
  ConsumerState<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<FriendsTab> {
  final _usernameCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendFriendRequest() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) return;

    try {
      await SocialActions.sendFriendRequest(username);
      _usernameCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to @$username'),
            backgroundColor: const Color(kColorUnlockedHex),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests = ref.watch(pendingFriendRequestsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Add friend section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Friend',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(
                          hintText: '@username',
                          prefixIcon: Icon(Icons.alternate_email),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _sendFriendRequest,
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Pending requests
        pendingRequests.when(
          data: (requests) {
            if (requests.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Friend Requests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...requests.map((req) => _FriendRequestCard(request: req)),
                const SizedBox(height: 16),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Group section
        _GroupSection(),
      ],
    );
  }
}

class _FriendRequestCard extends ConsumerWidget {
  final FriendRequest request;

  const _FriendRequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF1A1A2E),
          child: Icon(Icons.person, color: Color(kColorAccent)),
        ),
        title: Text('@${request.fromUid}'),
        subtitle: const Text('wants to be your friend'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => SocialActions.acceptFriendRequest(request),
              icon: const Icon(Icons.check, color: Color(kColorUnlockedHex)),
            ),
            IconButton(
              onPressed: () =>
                  SocialActions.declineFriendRequest(request.id),
              icon: const Icon(Icons.close, color: Color(kColorHusker)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends ConsumerState<_GroupSection> {
  final _groupNameCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();
  bool _showCreate = false;
  bool _showJoin = false;

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _inviteCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_groupNameCtrl.text.isEmpty) return;
    try {
      await SocialActions.createGroup(_groupNameCtrl.text.trim(), 'default');
      _groupNameCtrl.clear();
      setState(() => _showCreate = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _joinGroup() async {
    if (_inviteCodeCtrl.text.isEmpty) return;
    final group = await SocialActions.joinGroupByCode(_inviteCodeCtrl.text.trim());
    _inviteCodeCtrl.clear();
    setState(() => _showJoin = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(group != null
              ? 'Joined ${group.name}!'
              : 'Invalid invite code'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeGroup = ref.watch(activeGroupProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trip Group', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),

        // Active group
        activeGroup.when(
          data: (group) {
            if (group != null) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('👥', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(
                            group.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            '${group.memberIds.length} members',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Invite code
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: const Color(kColorAccent)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Invite Code: ',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              group.inviteCode,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: const Color(kColorAccent),
                                    letterSpacing: 4,
                                    fontFamily: 'monospace',
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                // Create group
                if (_showCreate)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _groupNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Group Name',
                              hintText: 'e.g. France 2026 Crew',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    setState(() => _showCreate = false),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _createGroup,
                                child: const Text('Create'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_showJoin)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _inviteCodeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Invite Code',
                              hintText: 'e.g. FR2026',
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    setState(() => _showJoin = false),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _joinGroup,
                                child: const Text('Join'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _showCreate = true),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Group'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _showJoin = true),
                          icon: const Icon(Icons.group_add),
                          label: const Text('Join Group'),
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
