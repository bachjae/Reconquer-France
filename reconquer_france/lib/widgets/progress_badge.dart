import 'package:flutter/material.dart';
import '../core/constants.dart';

class ProgressBadge extends StatelessWidget {
  final int unlockedCount;

  const ProgressBadge({required this.unlockedCount, super.key});

  double get percent => (unlockedCount / TOTAL_FRANCE_HEXES) * 100;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(kColorAccent).withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(kColorAccent).withOpacity(0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini progress arc
          SizedBox(
            width: 32,
            height: 32,
            child: CustomPaint(
              painter: _ProgressArcPainter(percent: percent / 100),
              child: Center(
                child: Text(
                  '🇫🇷',
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
                '${percent.toStringAsFixed(percent < 0.1 ? 3 : 1)}%',
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(kColorAccent),
                ),
              ),
              Text(
                '$unlockedCount cells',
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

  _ProgressArcPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = const Color(0xFF2A2A4E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = const Color(kColorAccent)
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
  bool shouldRepaint(_ProgressArcPainter old) => old.percent != percent;
}
