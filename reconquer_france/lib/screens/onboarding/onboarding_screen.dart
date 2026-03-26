import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Explore France',
      subtitle: 'Every step you take unlocks a piece of France.\nWatch the map come alive as you travel.',
      illustration: const ExploreIllustration(),
      emoji: '🗺️',
    ),
    OnboardingPage(
      title: 'Capture Memories',
      subtitle: 'Photos you take are automatically pinned to the hex cell where they were taken.',
      illustration: const CaptureIllustration(),
      emoji: '📸',
    ),
    OnboardingPage(
      title: 'With Your Crew',
      subtitle: 'Travel with friends, share your map, and use Corn & Husker for group coordination.',
      illustration: const CrewIllustration(),
      emoji: '👥',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (context, i) {
              return _OnboardingPageView(page: _pages[i]);
            },
          ),
          // Bottom controls
          Positioned(
            bottom: 60,
            left: 32,
            right: 32,
            child: Column(
              children: [
                SmoothPageIndicator(
                  controller: _pageController,
                  count: _pages.length,
                  effect: const ExpandingDotsEffect(
                    activeDotColor: Color(kColorAccent),
                    dotColor: Color(0xFF2A2A4E),
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 4,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: Text(
                          'Back',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white54),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          'Skip',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white54),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: _currentPage == _pages.length - 1
                          ? _finish
                          : () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? "Let's Go! 🚀"
                            : 'Next',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final Widget illustration;
  final String emoji;

  const OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.emoji,
  });
}

class _OnboardingPageView extends StatelessWidget {
  final OnboardingPage page;

  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final illustrationH = (constraints.maxHeight * 0.36).clamp(140.0, 260.0);
        final vGap = (constraints.maxHeight * 0.04).clamp(8.0, 32.0);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(32, vGap * 2, 32, 180),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: illustrationH,
                width: double.infinity,
                child: page.illustration,
              ),
              SizedBox(height: vGap * 1.2),
              Text(
                page.emoji,
                style: const TextStyle(fontSize: 44),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              SizedBox(height: vGap * 0.6),
              Text(
                page.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(kColorAccent),
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),
              SizedBox(height: vGap * 0.6),
              Text(
                page.subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        );
      },
    );
  }
}

// ─── Illustrations ───────────────────────────────────────────────────────────

class ExploreIllustration extends StatefulWidget {
  const ExploreIllustration({super.key});

  @override
  State<ExploreIllustration> createState() => _ExploreIllustrationState();
}

class _ExploreIllustrationState extends State<ExploreIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return CustomPaint(
          painter: _ExploreHexPainter(progress: _ctrl.value),
        );
      },
    );
  }
}

class _ExploreHexPainter extends CustomPainter {
  final double progress;

  _ExploreHexPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final lockedPaint = Paint()
      ..color = const Color(kColorLockedHex)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(kColorLockedHexBorder)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final unlockedPaint = Paint()
      ..color = const Color(kColorUnlockedHex)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = const Color(kColorUnlockedHex).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    const rows = 7;
    const cols = 9;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    final r = cellW * 0.45;

    // Total cells to unlock
    final totalUnlocked = (rows * cols * progress).round();
    int unlockedCount = 0;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = (col + 0.5) * cellW + (row.isOdd ? cellW / 2 : 0);
        final cy = (row + 0.5) * cellH;

        if (cx > size.width) continue;

        final hexPath = _hexPath(cx, cy, r);
        final isUnlocked = unlockedCount < totalUnlocked;
        if (isUnlocked) unlockedCount++;

        if (isUnlocked) {
          canvas.drawPath(hexPath, glowPaint);
          canvas.drawPath(hexPath, unlockedPaint);
        } else {
          canvas.drawPath(hexPath, lockedPaint);
          canvas.drawPath(hexPath, borderPaint);
        }
      }
    }
  }

  Path _hexPath(double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * pi / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_ExploreHexPainter old) => old.progress != progress;
}

class CaptureIllustration extends StatelessWidget {
  const CaptureIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Phone frame
        Container(
          width: 160,
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(kColorAccent), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, color: Color(kColorAccent), size: 48),
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(kColorUnlockedHex),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('📍', style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        // Photo pins flying out
        ...List.generate(4, (i) {
          final angle = (i * 90.0) * pi / 180;
          return Positioned(
            left: 160 + cos(angle) * 80,
            top: 120 + sin(angle) * 60,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(kColorUnlockedHex),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(kColorAccent)),
              ),
              child: const Icon(Icons.photo, size: 16, color: Colors.white),
            ).animate(delay: Duration(milliseconds: i * 200))
                .scale(duration: 400.ms),
          );
        }),
      ],
    );
  }
}

class CrewIllustration extends StatelessWidget {
  const CrewIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(kColorUnlockedHex),
      const Color(0xFF1A3A6E),
      const Color(0xFF7A1F2D),
      const Color(0xFF6B4F12),
    ];
    final emojis = ['🌽', '🦅', '🗼', '🍷'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(kColorAccent), width: 2),
                ),
                child: Center(
                  child: Text(emojis[i],
                      style: const TextStyle(fontSize: 24)),
                ),
              ).animate(delay: Duration(milliseconds: i * 150))
                  .scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 8),
              // Small hex cells belonging to each user
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (j) {
                  return Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: colors[i].withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      }),
    );
  }
}
