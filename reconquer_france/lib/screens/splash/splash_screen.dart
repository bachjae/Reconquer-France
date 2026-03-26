import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                              color: const Color(kColorAccent).withValues(alpha: 0.7),
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
      ..color = const Color(kColorAccent).withValues(alpha: 0.3)
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
      ..color = const Color(kColorUnlockedHex).withValues(alpha: progress * 0.6)
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

  // France outline — normalized from bounding box (W=-5.1, E=9.6, S=41.4, N=51.1)
  // x=(lng+5.1)/14.7  y=1-(lat-41.4)/9.7
  List<Offset> _getFranceOutlinePoints() {
    return [
      const Offset(0.51, 0.01), // Dunkirk
      const Offset(0.46, 0.03), // Calais/Boulogne
      const Offset(0.42, 0.09), // Dieppe
      const Offset(0.36, 0.14), // Fécamp
      const Offset(0.34, 0.17), // Le Havre
      const Offset(0.32, 0.20), // Caen
      const Offset(0.26, 0.20), // Cotentin base west
      const Offset(0.22, 0.15), // Cherbourg tip
      const Offset(0.27, 0.19), // Cotentin base east
      const Offset(0.24, 0.24), // Granville
      const Offset(0.21, 0.25), // Saint-Malo
      const Offset(0.15, 0.23), // North Brittany
      const Offset(0.09, 0.25), // Morlaix
      const Offset(0.03, 0.27), // Brest
      const Offset(0.02, 0.32), // Pointe du Raz
      const Offset(0.08, 0.35), // South Brittany
      const Offset(0.14, 0.37), // Lorient/Quiberon
      const Offset(0.19, 0.40), // Loire mouth
      const Offset(0.22, 0.46), // Vendée coast
      const Offset(0.26, 0.52), // La Rochelle
      const Offset(0.27, 0.59), // Charente
      const Offset(0.25, 0.67), // Arcachon/Gironde
      const Offset(0.23, 0.77), // Biarritz
      const Offset(0.26, 0.82), // Pyrenees west
      const Offset(0.35, 0.87), // Central Pyrenees
      const Offset(0.46, 0.87), // Eastern Pyrenees
      const Offset(0.54, 0.88), // Perpignan
      const Offset(0.57, 0.92), // Cap Cerbère (SE tip)
      const Offset(0.55, 0.82), // Narbonne
      const Offset(0.61, 0.79), // Sète
      const Offset(0.66, 0.78), // Montpellier
      const Offset(0.72, 0.80), // Marseille
      const Offset(0.75, 0.83), // Toulon
      const Offset(0.82, 0.78), // Cannes
      const Offset(0.85, 0.75), // Nice
      const Offset(0.87, 0.73), // Menton/Italian border
      const Offset(0.88, 0.62), // Alpine border
      const Offset(0.84, 0.53), // Geneva/Swiss border
      const Offset(0.87, 0.45), // Swiss border north
      const Offset(0.87, 0.37), // Basel
      const Offset(0.88, 0.28), // Strasbourg/Alsace
      const Offset(0.87, 0.21), // Rhine border
      const Offset(0.83, 0.16), // German border
      const Offset(0.78, 0.11), // Luxembourg
      const Offset(0.72, 0.07), // Belgian border/Ardennes
      const Offset(0.65, 0.04), // Belgian border west
      const Offset(0.57, 0.02), // North coast
      const Offset(0.51, 0.01), // Back to Dunkirk
    ];
  }

  @override
  bool shouldRepaint(FranceOutlinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
