import 'package:flutter/material.dart';
import '../core/constants.dart';

class ProgressBadge extends StatelessWidget {
  final int unlockedCount;
  final bool testMode;

  const ProgressBadge({
    required this.unlockedCount,
    this.testMode = false,
    super.key,
  });

  double get percent => (unlockedCount / TOTAL_FRANCE_HEXES) * 100;

  @override
  Widget build(BuildContext context) {
    final arcValue = testMode
        ? (unlockedCount / 300).clamp(0.0, 1.0) // ~300 hexes in Lincoln area
        : (percent / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: testMode
              ? Colors.orange.withValues(alpha: 0.7)
              : const Color(kColorAccent).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (testMode ? Colors.orange : const Color(kColorAccent))
                .withValues(alpha: 0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CustomPaint(
              painter: _ProgressArcPainter(
                percent: arcValue,
                color: testMode ? Colors.orange : const Color(kColorAccent),
              ),
              child: Center(
                child: Text(
                  testMode ? '🧪' : '🇫🇷',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                testMode
                    ? '$unlockedCount cells'
                    : '${percent.toStringAsFixed(percent < 0.1 ? 3 : 1)}%',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: testMode ? Colors.orange : const Color(kColorAccent),
                ),
              ),
              Text(
                testMode ? 'Lincoln NE' : 'of France',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressArcPainter extends CustomPainter {
  final double percent;
  final Color color;

  _ProgressArcPainter({required this.percent, this.color = const Color(kColorAccent)});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = const Color(0xFF2A2A4E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);

    // Track
    canvas.drawArc(rect, -2.36, 4.71, false, trackPaint);
    // Progress
    canvas.drawArc(rect, -2.36, 4.71 * percent, false, progressPaint);
  }

  @override
  bool shouldRepaint(_ProgressArcPainter old) => old.percent != percent || old.color != color;
}
