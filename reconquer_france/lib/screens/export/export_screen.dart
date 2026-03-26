
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/map_provider.dart';
import '../../providers/photo_provider.dart';
import '../../providers/auth_provider.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _generating = false;

  Future<void> _exportAndShare() async {
    setState(() => _generating = true);

    try {
      // Capture the widget as image
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/reconquer_france_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'My France Conquest',
        text: 'Check out my progress reconquering France! 🇫🇷',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCells = ref.watch(unlockedCellsProvider);
    final photos = ref.watch(allPhotosProvider);
    final profile = ref.watch(refreshableProfileProvider);
    final percent = (unlockedCells.length / TOTAL_FRANCE_HEXES * 100);

    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      appBar: AppBar(
        title: Text(
          'Export & Share',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            onPressed: _generating ? null : _exportAndShare,
            icon: _generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share, color: Color(kColorAccent)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Preview card (this gets exported)
            Center(
              child: RepaintBoundary(
                key: _repaintKey,
                child: _ExportCard(
                  unlockedCells: unlockedCells,
                  photos: photos,
                  displayName: profile.value?.displayName ?? 'Traveler',
                  avatarEmoji: profile.value?.avatarEmoji ?? '🌽',
                  percent: percent,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generating ? null : _exportAndShare,
                  icon: _generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.share),
                  label: Text(_generating ? 'Generating...' : 'Share to Instagram'),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final Set<String> unlockedCells;
  final List<Map<String, dynamic>> photos;
  final String displayName;
  final String avatarEmoji;
  final double percent;

  const _ExportCard({
    required this.unlockedCells,
    required this.photos,
    required this.displayName,
    required this.avatarEmoji,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    // Instagram story format (9:16 aspect ratio)
    final width = MediaQuery.of(context).size.width - 32;
    final height = width * 16 / 9;

    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        color: Color(kColorBackground),
      ),
      child: Stack(
        children: [
          // France map background
          Positioned.fill(
            child: CustomPaint(
              painter: _ExportMapPainter(
                unlockedCells: unlockedCells,
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // Photo mosaic (top 9 photos in hex cutouts)
                if (photos.isNotEmpty) _PhotoMosaic(photos: photos.take(9).toList()),

                const Spacer(),

                // Stats
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(kColorAccent).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Color(kColorAccent),
                        ),
                      ),
                      const Text(
                        'of France Reconquered',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$avatarEmoji $displayName',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMMM yyyy').format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Watermark
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('⚜️', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text(
                      'Reconquer France',
                      style: TextStyle(
                        color: Color(kColorAccent),
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoMosaic extends StatelessWidget {
  final List<Map<String, dynamic>> photos;

  const _PhotoMosaic({required this.photos});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Center large hex
          _HexPhoto(photoData: photos[0], size: 100),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (photos.length > 1)
                _HexPhoto(photoData: photos[1], size: 70),
              const SizedBox(height: 8),
              if (photos.length > 2)
                _HexPhoto(photoData: photos[2], size: 70),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (photos.length > 3)
                _HexPhoto(photoData: photos[3], size: 70),
              const SizedBox(height: 8),
              if (photos.length > 4)
                _HexPhoto(photoData: photos[4], size: 70),
            ],
          ),
        ],
      ),
    );
  }
}

class _HexPhoto extends StatelessWidget {
  final Map<String, dynamic> photoData;
  final double size;

  const _HexPhoto({required this.photoData, required this.size});

  @override
  Widget build(BuildContext context) {
    final localPath = photoData['localPath'] as String?;

    return ClipPath(
      clipper: _HexClipper(),
      child: SizedBox(
        width: size,
        height: size,
        child: localPath != null
            ? Image.file(
                File(localPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(kColorUnlockedHex),
                  child: const Icon(Icons.photo, color: Colors.white54),
                ),
              )
            : Container(
                color: const Color(kColorUnlockedHex),
              ),
      ),
    );
  }
}

class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(size.width, size.height) / 2;

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
  bool shouldReclip(_HexClipper old) => false;
}

class _ExportMapPainter extends CustomPainter {
  final Set<String> unlockedCells;

  _ExportMapPainter({required this.unlockedCells});

  @override
  void paint(Canvas canvas, Size size) {
    // France border glow
    final glowPaint = Paint()
      ..color = const Color(kColorAccent).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(kColorAccent)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final francePath = _scaledFrancePath(size);
    canvas.drawPath(francePath, glowPaint);
    canvas.drawPath(francePath, borderPaint);

    // Unlocked cells as dots
    final cellPaint = Paint()
      ..color = const Color(kColorUnlockedHex).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    for (final hexId in unlockedCells.take(500)) {
      try {
        final parts = hexId.split(':');
        if (parts.length != 2) continue;
        // Approximate position
        final col = double.tryParse(parts[0]) ?? 0;
        final row = double.tryParse(parts[1]) ?? 0;
        // Normalize to France bounds
        final lat = row * HEX_SIZE_KM / 111.0;
        final lng = col * HEX_SIZE_KM / 111.0;
        final x = ((lng - FRANCE_WEST) / (FRANCE_EAST - FRANCE_WEST)) * size.width;
        final y = (1 - (lat - FRANCE_SOUTH) / (FRANCE_NORTH - FRANCE_SOUTH)) * size.height;
        canvas.drawCircle(Offset(x, y), 3, cellPaint);
      } catch (_) {}
    }
  }

  // France outline normalized to [0,1] — matches splash screen outline
  Path _scaledFrancePath(Size size) {
    const points = [
      [0.51, 0.01], [0.46, 0.03], [0.42, 0.09], [0.36, 0.14],
      [0.34, 0.17], [0.32, 0.20], [0.26, 0.20], [0.22, 0.15],
      [0.27, 0.19], [0.24, 0.24], [0.21, 0.25], [0.15, 0.23],
      [0.09, 0.25], [0.03, 0.27], [0.02, 0.32], [0.08, 0.35],
      [0.14, 0.37], [0.19, 0.40], [0.22, 0.46], [0.26, 0.52],
      [0.27, 0.59], [0.25, 0.67], [0.23, 0.77], [0.26, 0.82],
      [0.35, 0.87], [0.46, 0.87], [0.54, 0.88], [0.57, 0.92],
      [0.55, 0.82], [0.61, 0.79], [0.66, 0.78], [0.72, 0.80],
      [0.75, 0.83], [0.82, 0.78], [0.85, 0.75], [0.87, 0.73],
      [0.88, 0.62], [0.84, 0.53], [0.87, 0.45], [0.87, 0.37],
      [0.88, 0.28], [0.87, 0.21], [0.83, 0.16], [0.78, 0.11],
      [0.72, 0.07], [0.65, 0.04], [0.57, 0.02], [0.51, 0.01],
    ];

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = points[i][0] * size.width;
      final y = points[i][1] * size.height;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_ExportMapPainter old) =>
      old.unlockedCells.length != unlockedCells.length;
}
