import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../providers/photo_provider.dart';
import '../../services/hex_grid_service.dart';

/// Instagram-style Stories viewer — one hex cell per story page.
/// Each page shows photos from that hex with an animated progress bar.
class HexStoriesScreen extends ConsumerStatefulWidget {
  /// If [startHexId] is provided, open that hex first.
  final String? startHexId;

  const HexStoriesScreen({this.startHexId, super.key});

  @override
  ConsumerState<HexStoriesScreen> createState() => _HexStoriesScreenState();
}

class _HexStoriesScreenState extends ConsumerState<HexStoriesScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentPage = 0;

  // Each "story" is a list of photos for one hex
  List<_HexStory> _stories = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(vsync: this);
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _advancePage();
      }
    });
    // Build stories on first frame — ref is available immediately in
    // ConsumerState.initState() in Riverpod 2.x
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildStories());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // intentionally empty — stories are built once in initState
  }

  void _buildStories() {
    final photos = ref.read(allPhotosProvider);

    // Group photos by hexId
    final Map<String, List<Map<String, dynamic>>> byHex = {};
    for (final photo in photos) {
      final hexId = photo['hexId'] as String? ?? '';
      if (hexId.isEmpty) continue;
      byHex.putIfAbsent(hexId, () => []).add(photo);
    }

    _stories = byHex.entries
        .map((e) => _HexStory(hexId: e.key, photos: e.value))
        .toList()
      ..sort((a, b) {
        final aDate = a.photos.last['takenAt'] as String? ?? '';
        final bDate = b.photos.last['takenAt'] as String? ?? '';
        return bDate.compareTo(aDate);
      });

    // Find start index
    int startIndex = 0;
    if (widget.startHexId != null) {
      final idx = _stories.indexWhere((s) => s.hexId == widget.startHexId);
      if (idx >= 0) startIndex = idx;
    }

    setState(() => _currentPage = startIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_stories.isNotEmpty) {
        _pageController.jumpToPage(startIndex);
        _startProgress();
      }
    });
  }

  void _startProgress() {
    _progressController.reset();
    if (_stories.isEmpty) return;
    // Each story auto-advances after 4s
    _progressController.duration = const Duration(seconds: 4);
    _progressController.forward();
  }

  void _advancePage() {
    if (_currentPage < _stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📷', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                'No stories yet',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            _progressController.stop();
            _previousPage();
          } else if (details.globalPosition.dx > screenWidth * 2 / 3) {
            _progressController.stop();
            _advancePage();
          } else {
            // Middle tap — pause/resume
            if (_progressController.isAnimating) {
              _progressController.stop();
            } else {
              _progressController.forward();
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Page view
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _stories.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                _startProgress();
              },
              itemBuilder: (context, i) {
                return _StoryPage(story: _stories[i]);
              },
            ),

            // Top UI: progress bars + close
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    12, MediaQuery.of(context).padding.top + 8, 12, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Column(
                  children: [
                    // Progress bar row
                    Row(
                      children: List.generate(_stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: _StoryProgressBar(
                              isActive: i == _currentPage,
                              isPast: i < _currentPage,
                              progressController: _progressController,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),

                    // Header row
                    Row(
                      children: [
                        const Text('⚜️',
                            style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _stories[_currentPage].hexId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom info bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomBar(story: _stories[_currentPage]),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryProgressBar extends StatelessWidget {
  final bool isActive;
  final bool isPast;
  final AnimationController progressController;

  const _StoryProgressBar({
    required this.isActive,
    required this.isPast,
    required this.progressController,
  });

  @override
  Widget build(BuildContext context) {
    if (isPast) {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    if (!isActive) {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white30,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return AnimatedBuilder(
      animation: progressController,
      builder: (_, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progressController.value,
            backgroundColor: Colors.white30,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            minHeight: 3,
          ),
        );
      },
    );
  }
}

class _StoryPage extends StatefulWidget {
  final _HexStory story;

  const _StoryPage({required this.story});

  @override
  State<_StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<_StoryPage> {
  int _photoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final photo = widget.story.photos[_photoIndex];
    final localPath = photo['localPath'] as String?;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! > 300) {
          Navigator.pop(context);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          if (localPath != null)
            Image.file(
              File(localPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          else
            _placeholder(),

          // Multi-photo indicator dots
          if (widget.story.photos.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.story.photos.length,
                  (i) => GestureDetector(
                    onTap: () => setState(() => _photoIndex = i),
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _photoIndex
                            ? const Color(kColorAccent)
                            : Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF0A0A0F),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white24, size: 64),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final _HexStory story;

  const _BottomBar({required this.story});

  @override
  Widget build(BuildContext context) {
    final center = HexGridService.hexIdToCenter(story.hexId);

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 14, color: Color(kColorAccent)),
                  const SizedBox(width: 4),
                  Text(
                    '${center.latitude.toStringAsFixed(4)}°N, '
                    '${center.longitude.toStringAsFixed(4)}°E',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${story.photos.length} photo${story.photos.length > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(kColorAccent).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Conquered ✓',
              style: TextStyle(
                color: Color(kColorAccent),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HexStory {
  final String hexId;
  final List<Map<String, dynamic>> photos;

  const _HexStory({required this.hexId, required this.photos});
}
