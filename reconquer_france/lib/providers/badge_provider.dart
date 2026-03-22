import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/region_badge.dart';
import '../services/hex_grid_service.dart';
import 'map_provider.dart';

/// Computes per-region unlock progress from the local unlocked cells.
final regionProgressProvider = Provider<List<RegionProgress>>((ref) {
  final unlockedCells = ref.watch(unlockedCellsProvider);

  // Count cells per region
  final Map<String, int> regionCounts = {
    for (final r in kFranceRegions) r.id: 0,
  };

  for (final hexId in unlockedCells) {
    final center = HexGridService.hexIdToCenter(hexId);
    for (final region in kFranceRegions) {
      if (region.containsPoint(center.latitude, center.longitude)) {
        regionCounts[region.id] = (regionCounts[region.id] ?? 0) + 1;
        break; // a cell belongs to at most one region
      }
    }
  }

  return kFranceRegions.map((region) {
    final count = regionCounts[region.id] ?? 0;
    final percent = (count / region.estimatedHexes) * 100.0;
    return RegionProgress(
      region: region,
      unlockedCells: count,
      percent: percent.clamp(0.0, 100.0),
      tier: tierForPercent(percent),
    );
  }).toList()
    ..sort((a, b) => b.percent.compareTo(a.percent));
});

/// Total badges earned (any tier other than none).
final earnedBadgeCountProvider = Provider<int>((ref) {
  final progress = ref.watch(regionProgressProvider);
  return progress.where((p) => p.tier != BadgeTier.none).length;
});
