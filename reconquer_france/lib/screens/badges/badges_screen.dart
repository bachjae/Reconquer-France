import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../models/region_badge.dart';
import '../../providers/badge_provider.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(regionProgressProvider);
    final earned = ref.watch(earnedBadgeCountProvider);

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      appBar: AppBar(
        backgroundColor: const Color(kColorBackground),
        title: Text(
          'Region Badges',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontFamily: 'PlayfairDisplay'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(kColorAccent).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(kColorAccent).withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$earned / ${kFranceRegions.length}',
                  style: const TextStyle(
                    color: Color(kColorAccent),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tier legend
          _TierLegend(),
          const Divider(color: Color(0xFF2A2A4E), height: 1),

          // Region grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: progress.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, i) {
                return _RegionCard(progress: progress[i]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TierLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tiers = [
      (BadgeTier.bronze, '5%'),
      (BadgeTier.silver, '25%'),
      (BadgeTier.gold, '50%'),
      (BadgeTier.platinum, '75%'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tiers.map((t) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tierEmoji(t.$1), style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                t.$2,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white54),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  final RegionProgress progress;

  const _RegionCard({required this.progress});

  Color get _tierColor {
    switch (progress.tier) {
      case BadgeTier.platinum:
        return const Color(0xFF88DDFF);
      case BadgeTier.gold:
        return const Color(kColorAccent);
      case BadgeTier.silver:
        return const Color(0xFFB0B0C8);
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.none:
        return const Color(0xFF2A2A4E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = progress.tier != BadgeTier.none;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? _tierColor.withValues(alpha: 0.6) : const Color(0xFF2A2A4E),
          width: unlocked ? 1.5 : 1,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: _tierColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge tier icon
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _tierColor.withValues(alpha: 0.12),
                    border: Border.all(
                        color: _tierColor.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      unlocked
                          ? progress.region.emoji
                          : '🔒',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                if (unlocked)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Text(
                      tierEmoji(progress.tier),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Region name
            Text(
              progress.region.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: unlocked ? Colors.white : Colors.white38,
                    fontSize: 12,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.percent / 100.0,
                backgroundColor: const Color(0xFF2A2A4E),
                valueColor: AlwaysStoppedAnimation(_tierColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),

            // Percent text
            Text(
              '${progress.percent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 11,
                color: unlocked ? _tierColor : Colors.white24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${progress.unlockedCells} cells',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 10, color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }
}
