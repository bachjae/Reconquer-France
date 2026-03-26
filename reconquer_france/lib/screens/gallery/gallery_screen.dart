import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/photo_provider.dart';
import '../../providers/map_provider.dart';
import '../../services/hex_grid_service.dart';
import 'hex_stories_screen.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  bool _isGridView = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    // Auto-import once when the gallery opens if no photos are loaded yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(allPhotosProvider).isEmpty) {
        _importPhotos(silent: true);
      }
    });
  }

  Future<void> _importPhotos({bool silent = false}) async {
    if (_importing) return;
    final tripId = ref.read(currentTripIdProvider) ?? 'local';

    setState(() => _importing = true);
    await ref.read(allPhotosProvider.notifier).importFromLibrary(tripId);
    if (mounted) setState(() => _importing = false);
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(allPhotosProvider);

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(kColorBackground),
            title: Text(
              'Gallery',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            actions: [
              // Stories button
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HexStoriesScreen()),
                ),
                icon: const Icon(Icons.auto_stories_outlined,
                    color: Color(kColorAccent)),
                tooltip: 'Stories',
              ),
              // Toggle view
              IconButton(
                onPressed: () =>
                    setState(() => _isGridView = !_isGridView),
                icon: Icon(
                  _isGridView
                      ? Icons.map_outlined
                      : Icons.grid_view,
                  color: const Color(kColorAccent),
                ),
              ),
              // Import button
              IconButton(
                onPressed: _importing ? null : () => _importPhotos(),
                icon: _importing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(kColorAccent)),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined,
                        color: Color(kColorAccent)),
              ),
            ],
          ),

          // Content
          if (photos.isEmpty)
            const SliverFillRemaining(
              child: _EmptyGallery(),
            )
          else if (_isGridView)
            _PhotoGrid(photos: photos)
          else
            _MapPhotoView(photos: photos),
        ],
      ),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📷', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No Photos Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Import photos from your library\nor take photos while exploring France.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<Map<String, dynamic>> photos;

  const _PhotoGrid({required this.photos});

  @override
  Widget build(BuildContext context) {
    // Sort by date
    final sorted = List<Map<String, dynamic>>.from(photos)
      ..sort((a, b) {
        final aDate = a['takenAt'] as String? ?? '';
        final bDate = b['takenAt'] as String? ?? '';
        return bDate.compareTo(aDate);
      });

    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            return _GridPhoto(photo: sorted[i]);
          },
          childCount: sorted.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
      ),
    );
  }
}

class _GridPhoto extends StatelessWidget {
  final Map<String, dynamic> photo;

  const _GridPhoto({required this.photo});

  @override
  Widget build(BuildContext context) {
    final localPath = photo['localPath'] as String?;
    final hexId = photo['hexId'] as String? ?? '';

    return GestureDetector(
      onTap: () => _showFullscreen(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          if (localPath != null)
            Image.file(
              File(localPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _photoPlaceholder(),
            )
          else
            _photoPlaceholder(),

          // Hex badge
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                hexId.length > 8 ? hexId.substring(0, 8) : hexId,
                style:
                    const TextStyle(color: Color(kColorAccent), fontSize: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Icon(Icons.image_outlined, color: Colors.white24),
    );
  }

  void _showFullscreen(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fullscreen, color: Color(kColorAccent)),
              title: const Text('View Photo'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => _FullscreenPhoto(photo: photo)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined,
                  color: Color(kColorAccent)),
              title: const Text('View Hex Stories'),
              onTap: () {
                Navigator.pop(context);
                final hexId = photo['hexId'] as String?;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          HexStoriesScreen(startHexId: hexId)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenPhoto extends StatelessWidget {
  final Map<String, dynamic> photo;

  const _FullscreenPhoto({required this.photo});

  @override
  Widget build(BuildContext context) {
    final localPath = photo['localPath'] as String?;
    final hexId = photo['hexId'] as String? ?? '';
    final lat = (photo['lat'] as num?)?.toDouble() ?? 0;
    final lng = (photo['lng'] as num?)?.toDouble() ?? 0;
    final takenAt = photo['takenAt'] as String?;
    DateTime? date;
    if (takenAt != null) {
      try {
        date = DateTime.parse(takenAt);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          if (localPath != null)
            InteractiveViewer(
              child: Image.file(
                File(localPath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, size: 64)),
              ),
            )
          else
            const Center(
              child: Icon(Icons.image_not_supported, size: 64,
                  color: Colors.white38),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  8, MediaQuery.of(context).padding.top + 4, 8, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // Bottom info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(context).padding.bottom + 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Color(kColorAccent)),
                      const SizedBox(width: 4),
                      Text(
                        '${lat.toStringAsFixed(4)}°N, ${lng.toStringAsFixed(4)}°E',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hex: $hexId',
                    style: const TextStyle(
                        color: Color(kColorAccent), fontSize: 12),
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMMM d, yyyy • HH:mm').format(date),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPhotoView extends ConsumerWidget {
  final List<Map<String, dynamic>> photos;

  const _MapPhotoView({required this.photos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedCells = ref.watch(unlockedCellsProvider);

    return SliverFillRemaining(
      child: Stack(
        children: [
          // France outline map view showing hex cells with photos
          CustomPaint(
            painter: _MapViewPainter(
              photos: photos,
              unlockedCells: unlockedCells,
            ),
          ),
          // Placeholder text
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${unlockedCells.length} cells explored\n${photos.length} photos',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapViewPainter extends CustomPainter {
  final List<Map<String, dynamic>> photos;
  final Set<String> unlockedCells;

  _MapViewPainter({required this.photos, required this.unlockedCells});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(kColorBackground);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw simplified France outline
    final borderPaint = Paint()
      ..color = const Color(kColorAccent)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Simple France outline scaling to fit
    final path = _francePath(size);
    canvas.drawPath(path, borderPaint);

    // Draw unlocked cells as small dots
    final cellPaint = Paint()
      ..color = const Color(kColorUnlockedHex).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    for (final hexId in unlockedCells.take(1000)) {
      final center = HexGridService.hexIdToCenter(hexId);
      final p = _latLngToOffset(
          center.latitude, center.longitude, size);
      canvas.drawCircle(p, 2, cellPaint);
    }

    // Draw photo markers
    final photoPaint = Paint()
      ..color = const Color(kColorAccent)
      ..style = PaintingStyle.fill;

    final Set<String> drawnHexes = {};
    for (final photo in photos) {
      final hexId = photo['hexId'] as String? ?? '';
      if (drawnHexes.contains(hexId)) continue;
      drawnHexes.add(hexId);

      final lat = (photo['lat'] as num?)?.toDouble() ?? 0;
      final lng = (photo['lng'] as num?)?.toDouble() ?? 0;
      final p = _latLngToOffset(lat, lng, size);
      canvas.drawCircle(p, 4, photoPaint);
    }
  }

  Offset _latLngToOffset(double lat, double lng, Size size) {
    final x = ((lng - FRANCE_WEST) / (FRANCE_EAST - FRANCE_WEST)) * size.width;
    final y =
        (1 - (lat - FRANCE_SOUTH) / (FRANCE_NORTH - FRANCE_SOUTH)) * size.height;
    return Offset(x, y);
  }

  Path _francePath(Size size) {
    final outlinePoints = [
      [0.50, 0.05], [0.65, 0.08], [0.75, 0.12], [0.82, 0.10],
      [0.88, 0.20], [0.90, 0.30], [0.92, 0.42], [0.88, 0.52],
      [0.85, 0.62], [0.80, 0.72], [0.72, 0.82], [0.62, 0.88],
      [0.50, 0.92], [0.38, 0.90], [0.28, 0.82], [0.20, 0.72],
      [0.15, 0.60], [0.08, 0.50], [0.05, 0.40], [0.08, 0.28],
      [0.15, 0.18], [0.10, 0.22], [0.12, 0.28], [0.18, 0.22],
      [0.15, 0.15], [0.22, 0.10], [0.35, 0.06], [0.50, 0.05],
    ];

    final path = Path();
    for (int i = 0; i < outlinePoints.length; i++) {
      final x = outlinePoints[i][0] * size.width;
      final y = outlinePoints[i][1] * size.height;
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
  bool shouldRepaint(_MapViewPainter old) =>
      old.photos.length != photos.length ||
      old.unlockedCells.length != unlockedCells.length;
}
