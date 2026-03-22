import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pathAnimation;
  late Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _pathAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated) {
        _navigated = true;
        _navigateNext();
      }
    });
  }

  Future<void> _navigateNext() async {
    final authState = ref.read(authStateProvider);
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    if (!mounted) return;

    if (authState.value != null) {
      context.go('/map');
    } else if (!hasSeenOnboarding) {
      context.go('/onboarding');
    } else {
      context.go('/auth/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated France outline
            SizedBox(
              width: 280,
              height: 280,
              child: AnimatedBuilder(
                animation: _pathAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: FranceOutlinePainter(
                      progress: _pathAnimation.value,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            // Title fade in
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, _) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    children: [
                      Text(
                        'Reconquer',
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(
                              color: const Color(kColorAccent),
                              letterSpacing: 4,
                              fontFamily: 'PlayfairDisplay',
                            ),
                      ),
                      Text(
                        'FRANCE',
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: Colors.white,
                                  letterSpacing: 12,
                                  fontFamily: 'PlayfairDisplay',
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Explore. Conquer. Remember.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(kColorAccent).withOpacity(0.7),
                              letterSpacing: 2,
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class FranceOutlinePainter extends CustomPainter {
  final double progress;

  const FranceOutlinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(kColorAccent)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Simplified France outline path (normalized 0-1 coordinates)
    final points = _getFranceOutlinePoints();
    if (points.isEmpty) return;

    final path = Path();
    final totalPoints = points.length;
    final visibleCount = (totalPoints * progress).round().clamp(1, totalPoints);

    // Transform to canvas coordinates
    List<Offset> canvasPoints = points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    path.moveTo(canvasPoints[0].dx, canvasPoints[0].dy);
    for (int i = 1; i < visibleCount; i++) {
      path.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
    }

    // Glow effect
    final glowPaint = Paint()
      ..color = const Color(kColorAccent).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Draw hex cells lighting up inside France
    if (progress > 0.5) {
      final hexProgress = (progress - 0.5) * 2.0;
      _drawHexCells(canvas, size, hexProgress);
    }
  }

  void _drawHexCells(Canvas canvas, Size size, double progress) {
    final rng = Random(42);
    final hexPaint = Paint()
      ..color = const Color(kColorUnlockedHex).withOpacity(progress * 0.6)
      ..style = PaintingStyle.fill;

    // Draw some random hex-like shapes inside France bounds
    final hexCount = (30 * progress).round();
    for (int i = 0; i < hexCount; i++) {
      final x = 0.2 + rng.nextDouble() * 0.6;
      final y = 0.15 + rng.nextDouble() * 0.7;
      final cx = x * size.width;
      final cy = y * size.height;
      final r = 8.0;

      final hexPath = Path();
      for (int j = 0; j < 6; j++) {
        final angle = (60 * j - 30) * pi / 180;
        final px = cx + r * cos(angle);
        final py = cy + r * sin(angle);
        if (j == 0) {
          hexPath.moveTo(px, py);
        } else {
          hexPath.lineTo(px, py);
        }
      }
      hexPath.close();
      canvas.drawPath(hexPath, hexPaint);
    }
  }

  // Simplified France outline — normalized coordinates (0=top-left, 1=bottom-right)
  List<Offset> _getFranceOutlinePoints() {
    return [
      // Starting from north, going clockwise (simplified)
      const Offset(0.50, 0.05), // North (near Belgium)
      const Offset(0.65, 0.08),
      const Offset(0.75, 0.12),
      const Offset(0.82, 0.10), // Alsace
      const Offset(0.88, 0.20),
      const Offset(0.90, 0.30),
      const Offset(0.92, 0.42), // Swiss/Italian border
      const Offset(0.88, 0.52),
      const Offset(0.85, 0.62),
      const Offset(0.80, 0.72), // Mediterranean coast
      const Offset(0.72, 0.82),
      const Offset(0.62, 0.88),
      const Offset(0.50, 0.92), // South coast
      const Offset(0.38, 0.90),
      const Offset(0.28, 0.82), // Spanish border
      const Offset(0.20, 0.72),
      const Offset(0.15, 0.60),
      const Offset(0.08, 0.50), // Bay of Biscay
      const Offset(0.05, 0.40),
      const Offset(0.08, 0.28),
      const Offset(0.15, 0.18), // Brittany
      const Offset(0.10, 0.22),
      const Offset(0.12, 0.28),
      const Offset(0.18, 0.22), // Cherbourg peninsula
      const Offset(0.15, 0.15),
      const Offset(0.22, 0.10),
      const Offset(0.35, 0.06), // North coast
      const Offset(0.50, 0.05), // Back to start
    ];
  }

  @override
  bool shouldRepaint(FranceOutlinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
