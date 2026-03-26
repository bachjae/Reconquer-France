import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../providers/streak_provider.dart';

/// A compact streak display widget — shows 🔥N or 🔥0 grayed out.
class StreakBadge extends ConsumerWidget {
  final bool compact;
  const StreakBadge({this.compact = true, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final active = streak.currentStreak > 0;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? const Color(kColorAccent).withValues(alpha: 0.15)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? const Color(kColorAccent).withValues(alpha: 0.6)
                : const Color(0xFF2A2A4E),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              active ? '🔥' : '💤',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Text(
              '${streak.currentStreak}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: active
                    ? const Color(kColorAccent)
                    : Colors.white38,
              ),
            ),
          ],
        ),
      );
    }

    // Full streak panel for profile
    return _FullStreakPanel(streak: streak);
  }
}

class _FullStreakPanel extends StatelessWidget {
  final StreakState streak;
  const _FullStreakPanel({required this.streak});

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
              const Text('🔥', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                'Exploration Streak',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _MiniStat(
                value: '${streak.currentStreak}',
                label: 'Current',
                color: const Color(kColorAccent),
              ),
              const SizedBox(width: 12),
              _MiniStat(
                value: '${streak.longestStreak}',
                label: 'Best',
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              _MiniStat(
                value: '${streak.totalDaysActive}',
                label: 'Total Days',
                color: Colors.lightBlue,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Last 7 days calendar
          Text(
            'Last 7 Days',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: streak.lastSevenDays.map((day) {
              final date = DateTime.parse(day.date);
              final dayLabel = ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                  [date.weekday - 1];
              return _DayDot(label: dayLabel, active: day.active);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.value,
    required this.label,
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
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String label;
  final bool active;

  const _DayDot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? const Color(kColorAccent).withValues(alpha: 0.85)
                : const Color(0xFF2A2A4E),
          ),
          child: Center(
            child: Text(
              active ? '🔥' : label,
              style: TextStyle(
                fontSize: active ? 14 : 11,
                color: active ? Colors.black : Colors.white38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
