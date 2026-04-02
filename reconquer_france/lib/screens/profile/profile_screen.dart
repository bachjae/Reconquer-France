import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import 'trip_history_screen.dart';
import '../../providers/map_provider.dart';
import '../../providers/badge_provider.dart';

import '../../providers/elevation_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/streak_badge.dart';
import '../../providers/test_mode_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(refreshableProfileProvider);
    final unlockedCount = ref.watch(unlockedCellsProvider).length;
    final percent = (unlockedCount / TOTAL_FRANCE_HEXES * 100);
    final earnedBadges = ref.watch(earnedBadgeCountProvider);
    final elevation = ref.watch(elevationProvider);

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
                        earnedBadges: earnedBadges,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Streak panel
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: StreakBadge(compact: false),
                    ),
                    const SizedBox(height: 20),

                    // Elevation panel
                    if (elevation.samplesCount > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ElevationPanel(stats: elevation),
                      ),
                    if (elevation.samplesCount > 0)
                      const SizedBox(height: 20),

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
                  color: const Color(kColorAccent).withValues(alpha: 0.3),
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
  final int earnedBadges;

  const _StatsGrid({
    required this.unlockedCount,
    required this.percent,
    required this.earnedBadges,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
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
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '$earnedBadges',
                label: 'Region Badges',
                emoji: '🏅',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                value: '${(percent * 5500).round()}',
                label: 'km² Explored',
                emoji: '📐',
              ),
            ),
          ],
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

class _ElevationPanel extends StatelessWidget {
  final ElevationStats stats;

  const _ElevationPanel({required this.stats});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏔️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text('Elevation Stats',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ElevStat(
                label: 'Max Alt.',
                value: '${stats.maxAltitude.round()}m',
                color: Colors.lightBlue,
              ),
              const SizedBox(width: 10),
              _ElevStat(
                label: 'Ascent',
                value: '↑${stats.totalAscent.round()}m',
                color: Colors.green,
              ),
              const SizedBox(width: 10),
              _ElevStat(
                label: 'Descent',
                value: '↓${stats.totalDescent.round()}m',
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ElevStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ElevStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 10, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testMode = ref.watch(testModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _SettingsTile(
          icon: Icons.history,
          title: 'Trip History',
          subtitle: 'Browse all your past trips and collections',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const TripHistoryScreen()),
          ),
        ),
        _SettingsTile(
          icon: Icons.emoji_events_outlined,
          title: 'Region Badges',
          subtitle: 'View your France region achievements',
          onTap: () => context.push('/badges'),
        ),
        _SettingsTile(
          icon: Icons.download_outlined,
          title: 'Offline Map',
          subtitle: 'Download France for offline use',
          onTap: () => context.push('/offline-tiles'),
        ),
        _SettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Corn & Husker alerts',
          onTap: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF12121A),
              title: const Text('Notifications'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You receive notifications for:',
                      style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 12),
                  Text('🌽  Corn alerts from group leaders',
                      style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 6),
                  Text('🚨  HUSKER emergency alerts',
                      style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 6),
                  Text('🎉  Cell milestones (100 / 500 / 1,000)',
                      style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 6),
                  Text('🔥  Streak milestones (3 / 7 / 14 / 30 days)',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy',
          subtitle: 'Location sharing settings',
          onTap: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF12121A),
              title: const Text('Privacy'),
              content: const Text(
                'Your location is only shared with your group '
                'members when you send a Corn or Husker alert.\n\n'
                'All other location data stays on your device.',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
        ),
        // Test mode toggle — unlocks Lincoln NE instead of France
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: testMode ? Colors.orange.withValues(alpha: 0.2) : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.science_outlined,
                color: testMode ? Colors.orange : const Color(kColorAccent), size: 20),
          ),
          title: Text('Test Mode (Lincoln NE)',
              style: Theme.of(context).textTheme.titleSmall),
          subtitle: Text(
            testMode ? 'Active — walk Lincoln NE to unlock hexes' : 'Simulate in Lincoln, Nebraska',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Switch(
            value: testMode,
            activeColor: Colors.orange,
            onChanged: (_) => ref.read(testModeProvider.notifier).toggle(),
          ),
          onTap: () => ref.read(testModeProvider.notifier).toggle(),
        ),
        _SettingsTile(
          icon: Icons.info_outlined,
          title: 'About',
          subtitle: 'Reconquer France v1.0',
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'Reconquer France',
            applicationVersion: '1.0.0',
            applicationLegalese:
                '© 2026 Reconquer France\nMap tiles © OpenStreetMap contributors, © CARTO',
            children: const [
              SizedBox(height: 16),
              Text(
                'Geo-gamified travel app for exploring France '
                'one hex at a time.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
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
