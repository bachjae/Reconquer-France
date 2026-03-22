import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/offline_tile_service.dart';

class OfflineTilesScreen extends StatefulWidget {
  const OfflineTilesScreen({super.key});

  @override
  State<OfflineTilesScreen> createState() => _OfflineTilesScreenState();
}

class _OfflineTilesScreenState extends State<OfflineTilesScreen> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';
  late bool _isDownloaded;

  @override
  void initState() {
    super.initState();
    _isDownloaded = OfflineTileService.isFranceDownloaded;
    _progress = OfflineTileService.downloadProgress;
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusMessage = 'Preparing download...';
    });

    await OfflineTileService.downloadFrance(
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _statusMessage =
                'Downloading tiles... ${(progress * 100).toInt()}%';
          });
        }
      },
      onComplete: () {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isDownloaded = true;
            _progress = 1.0;
            _statusMessage = 'Download complete!';
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _statusMessage = 'Error: $error';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: $error'),
              backgroundColor: const Color(kColorHusker),
            ),
          );
        }
      },
    );
  }

  Future<void> _removeDownload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Remove Offline Map'),
        content: const Text(
            'This will delete the offline France map (≈280 MB). You\'ll need Wi-Fi to use the map in remote areas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: Color(kColorHusker))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await OfflineTileService.removeFrance();
      if (mounted) {
        setState(() {
          _isDownloaded = false;
          _progress = 0.0;
          _statusMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(kColorBackground),
      appBar: AppBar(
        backgroundColor: const Color(kColorBackground),
        title: Text(
          'Offline Map',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            _StatusCard(
              isDownloaded: _isDownloaded,
              isDownloading: _isDownloading,
              progress: _progress,
            ),
            const SizedBox(height: 24),

            // Info section
            Text('France Offline Map',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.map_outlined,
              label: 'Coverage',
              value: 'Metropolitan France',
            ),
            _InfoRow(
              icon: Icons.zoom_in,
              label: 'Zoom levels',
              value: '0–12 (street level)',
            ),
            _InfoRow(
              icon: Icons.storage_outlined,
              label: 'Estimated size',
              value: OfflineTileService.estimatedSizeMb,
            ),
            _InfoRow(
              icon: Icons.update,
              label: 'Style',
              value: 'Mapbox Dark v11',
            ),
            const SizedBox(height: 24),

            // Progress bar (while downloading)
            if (_isDownloading) ...[
              Text(
                _statusMessage,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: const Color(kColorAccent)),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: const Color(0xFF2A2A4E),
                valueColor:
                    const AlwaysStoppedAnimation(Color(kColorAccent)),
                minHeight: 6,
              ),
              const SizedBox(height: 24),
            ],

            // Tip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(kColorAccent).withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(kColorAccent).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Download on Wi-Fi before your trip. The offline map lets you navigate rural France without mobile data.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Action button
            SizedBox(
              width: double.infinity,
              child: _isDownloaded
                  ? OutlinedButton.icon(
                      onPressed: _removeDownload,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove Offline Map'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(kColorHusker),
                        side: const BorderSide(color: Color(kColorHusker)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _isDownloading ? null : _startDownload,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(_isDownloading
                          ? 'Downloading...'
                          : 'Download France'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(kColorAccent),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isDownloaded;
  final bool isDownloading;
  final double progress;

  const _StatusCard({
    required this.isDownloaded,
    required this.isDownloading,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isDownloaded
        ? Colors.green
        : isDownloading
            ? const Color(kColorAccent)
            : Colors.white38;
    final IconData icon = isDownloaded
        ? Icons.check_circle_outline
        : isDownloading
            ? Icons.downloading_outlined
            : Icons.cloud_download_outlined;
    final String label = isDownloaded
        ? 'Downloaded & Ready'
        : isDownloading
            ? 'Downloading...'
            : 'Not Downloaded';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold)),
                if (isDownloading) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFF2A2A4E),
                    valueColor: const AlwaysStoppedAnimation(Color(kColorAccent)),
                    minHeight: 3,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(kColorAccent)),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
