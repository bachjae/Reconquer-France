/// Represents one of France's 13 metropolitan administrative regions.
class FranceRegion {
  final String id;
  final String name;
  final String emoji;
  final double northLat;
  final double southLat;
  final double westLng;
  final double eastLng;
  final int estimatedHexes;

  const FranceRegion({
    required this.id,
    required this.name,
    required this.emoji,
    required this.northLat,
    required this.southLat,
    required this.westLng,
    required this.eastLng,
    required this.estimatedHexes,
  });

  bool containsPoint(double lat, double lng) =>
      lat >= southLat && lat <= northLat && lng >= westLng && lng <= eastLng;
}

/// The 13 metropolitan regions of France with approximate bounding boxes.
const List<FranceRegion> kFranceRegions = [
  FranceRegion(
    id: 'idf',
    name: 'Île-de-France',
    emoji: '🗼',
    northLat: 49.24,
    southLat: 48.12,
    westLng: 1.44,
    eastLng: 3.56,
    estimatedHexes: 12000,
  ),
  FranceRegion(
    id: 'normandie',
    name: 'Normandie',
    emoji: '⚓',
    northLat: 50.00,
    southLat: 48.10,
    westLng: -1.98,
    eastLng: 2.00,
    estimatedHexes: 29000,
  ),
  FranceRegion(
    id: 'hdf',
    name: 'Hauts-de-France',
    emoji: '🏭',
    northLat: 51.10,
    southLat: 49.25,
    westLng: 1.40,
    eastLng: 4.25,
    estimatedHexes: 31000,
  ),
  FranceRegion(
    id: 'grandest',
    name: 'Grand Est',
    emoji: '🍺',
    northLat: 50.00,
    southLat: 47.40,
    westLng: 3.80,
    eastLng: 8.20,
    estimatedHexes: 57000,
  ),
  FranceRegion(
    id: 'bfc',
    name: 'Bourgogne-Franche-Comté',
    emoji: '🍷',
    northLat: 48.40,
    southLat: 46.20,
    westLng: 2.84,
    eastLng: 7.10,
    estimatedHexes: 47000,
  ),
  FranceRegion(
    id: 'ara',
    name: 'Auvergne-Rhône-Alpes',
    emoji: '🏔️',
    northLat: 46.62,
    southLat: 44.10,
    westLng: 2.06,
    eastLng: 7.20,
    estimatedHexes: 69000,
  ),
  FranceRegion(
    id: 'paca',
    name: 'Provence-Alpes-Côte d\'Azur',
    emoji: '🌊',
    northLat: 44.70,
    southLat: 43.15,
    westLng: 4.22,
    eastLng: 7.72,
    estimatedHexes: 31000,
  ),
  FranceRegion(
    id: 'occitanie',
    name: 'Occitanie',
    emoji: '☀️',
    northLat: 45.05,
    southLat: 42.30,
    westLng: -0.35,
    eastLng: 4.86,
    estimatedHexes: 72000,
  ),
  FranceRegion(
    id: 'na',
    name: 'Nouvelle-Aquitaine',
    emoji: '🏄',
    northLat: 46.96,
    southLat: 43.02,
    westLng: -1.78,
    eastLng: 2.06,
    estimatedHexes: 84000,
  ),
  FranceRegion(
    id: 'bretagne',
    name: 'Bretagne',
    emoji: '🦞',
    northLat: 48.90,
    southLat: 47.27,
    westLng: -5.15,
    eastLng: -1.03,
    estimatedHexes: 27000,
  ),
  FranceRegion(
    id: 'pdl',
    name: 'Pays de la Loire',
    emoji: '🏰',
    northLat: 48.40,
    southLat: 46.35,
    westLng: -2.58,
    eastLng: 0.99,
    estimatedHexes: 32000,
  ),
  FranceRegion(
    id: 'cvl',
    name: 'Centre-Val de Loire',
    emoji: '🌻',
    northLat: 48.55,
    southLat: 46.35,
    westLng: 0.06,
    eastLng: 3.80,
    estimatedHexes: 39000,
  ),
  FranceRegion(
    id: 'corse',
    name: 'Corse',
    emoji: '🦅',
    northLat: 43.06,
    southLat: 41.32,
    westLng: 8.50,
    eastLng: 9.58,
    estimatedHexes: 9000,
  ),
];

class RegionProgress {
  final FranceRegion region;
  final int unlockedCells;
  final double percent;
  final BadgeTier tier;

  const RegionProgress({
    required this.region,
    required this.unlockedCells,
    required this.percent,
    required this.tier,
  });
}

enum BadgeTier { none, bronze, silver, gold, platinum }

BadgeTier tierForPercent(double percent) {
  if (percent >= 75.0) return BadgeTier.platinum;
  if (percent >= 50.0) return BadgeTier.gold;
  if (percent >= 25.0) return BadgeTier.silver;
  if (percent >= 5.0) return BadgeTier.bronze;
  return BadgeTier.none;
}

String tierEmoji(BadgeTier tier) {
  switch (tier) {
    case BadgeTier.platinum:
      return '💎';
    case BadgeTier.gold:
      return '🥇';
    case BadgeTier.silver:
      return '🥈';
    case BadgeTier.bronze:
      return '🥉';
    case BadgeTier.none:
      return '🔒';
  }
}
