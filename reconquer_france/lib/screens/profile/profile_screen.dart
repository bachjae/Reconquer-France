import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/map_provider.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(refreshableProfileProvider);
    final unlockedCount = ref.watch(unlockedCellsProvider).length;
    final percent = (unlockedCount / TOTAL_FRANCE_HEXES * 100);

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(kColorBackground),
            pinned: true,
            title: Text(
              'Profile',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            actions: [
              IconButton(
                onPressed: () => context.push('/export'),
                icon: const Icon(Icons.ios_share, color: Color(kColorAccent)),
                tooltip: 'Export',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: profile.when(
              data: (p) {
                if (p == null) {
                  return const Center(child: Text('Loading...'));
                }
                return Column(
                  children: [
                    // Profile header
                    _ProfileHeader(
                      emoji: p.avatarEmoji,
                      displayName: p.displayName,
                      username: p.username,
                    ),
                    const SizedBox(height: 24),

                    // Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _StatsGrid(
                        unlockedCount: unlockedCount,
                        percent: percent,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Settings
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SettingsSection(),
                    ),

                    const SizedBox(height: 32),

                    // Sign out
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await AuthService().signOut();
                            if (context.mounted) {
                              context.go('/auth/login');
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white54,
                            side: const BorderSide(color: Color(0xFF2A2A4E)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                  child: Text('Failed to load profile')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String emoji;
  final String displayName;
  final String username;

  const _ProfileHeader({
    required this.emoji,
    required this.displayName,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1A2E),
            const Color(kColorBackground),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(kColorAccent), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(kColorAccent).withOpacity(0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 48)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '@$username',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color(kColorAccent)),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int unlockedCount;
  final double percent;

  const _StatsGrid({required this.unlockedCount, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: unlockedCount.toString(),
            label: 'Cells Unlocked',
            emoji: '🗺️',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: '${percent.toStringAsFixed(2)}%',
            label: 'France Conquered',
            emoji: '🇫🇷',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String emoji;

  const _StatCard({
    required this.value,
    required this.label,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4E)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(kColorAccent),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _SettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Corn & Husker alerts',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.download_outlined,
          title: 'Offline Map',
          subtitle: 'Download France for offline use',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy',
          subtitle: 'Location sharing settings',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.info_outlined,
          title: 'About',
          subtitle: 'Reconquer France v1.0',
          onTap: () {},
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(kColorAccent), size: 20),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}
