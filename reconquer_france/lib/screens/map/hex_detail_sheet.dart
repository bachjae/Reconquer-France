import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../providers/map_provider.dart';
import '../../providers/photo_provider.dart';

import '../../services/hex_grid_service.dart';

class HexDetailSheet extends ConsumerWidget {
  final String hexId;

  const HexDetailSheet({required this.hexId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedCells = ref.watch(unlockedCellsProvider);
    final isUnlocked = unlockedCells.contains(hexId);
    final photos = ref.watch(hexPhotosProvider(hexId));
    final center = HexGridService.hexIdToCenter(hexId);

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF12121A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A4E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    // Header
                    Row(
                      children: [
                        // Hex ID badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? const Color(kColorUnlockedHex).withValues(alpha: 0.3)
                                : const Color(kColorLockedHex),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isUnlocked
                                  ? const Color(kColorAccent)
                                  : const Color(kColorLockedHexBorder),
                            ),
                          ),
                          child: Text(
                            hexId,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: isUnlocked
                                      ? const Color(kColorAccent)
                                      : Colors.white38,
                                ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          isUnlocked ? Icons.lock_open : Icons.lock,
                          color: isUnlocked
                              ? const Color(kColorAccent)
                              : Colors.white38,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Status
                    if (!isUnlocked) ...[
                      _UnexploredCell(),
                    ] else ...[
                      // Coordinates
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Color(kColorAccent)),
                          const SizedBox(width: 4),
                          Text(
                            '${center.latitude.toStringAsFixed(4)}°N, '
                            '${center.longitude.toStringAsFixed(4)}°E',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Photos section
                      if (photos.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${photos.length} Photo${photos.length != 1 ? 's' : ''}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final photo = photos[i];
                              return _PhotoThumbnail(
                                photoData: photo,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.photo_camera_outlined,
                                  color: Colors.white38),
                              const SizedBox(width: 12),
                              Text(
                                'No photos yet in this cell',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.white38),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Add photo button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/camera');
                          },
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Add Photo Here'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnexploredCell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(kColorLockedHexBorder)),
      ),
      child: Column(
        children: [
          const Text('🔒', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Not Yet Explored',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Travel to this cell to unlock it.\nStay for ${kDwellSecondsRequired}s to claim it.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final Map<String, dynamic> photoData;

  const _PhotoThumbnail({required this.photoData});

  @override
  Widget build(BuildContext context) {
    final localPath = photoData['localPath'] as String?;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 120,
        height: 120,
        child: localPath != null
            ? Image.file(
                File(localPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Icon(Icons.image_outlined, color: Colors.white38),
    );
  }
}
