import 'dart:math';

// ─── France Bounding Box ────────────────────────────────────────────────────
const double FRANCE_NORTH = 51.1;
const double FRANCE_SOUTH = 41.3;
const double FRANCE_WEST = -5.2;
const double FRANCE_EAST = 9.6;

// ─── Lincoln NE Test Area ───────────────────────────────────────────────────
const double LINCOLN_NORTH = 40.95;
const double LINCOLN_SOUTH = 40.70;
const double LINCOLN_WEST = -96.85;
const double LINCOLN_EAST = -96.55;
const double LINCOLN_CENTER_LAT = 40.8258;
const double LINCOLN_CENTER_LNG = -96.6852;

// ─── Hex Grid ───────────────────────────────────────────────────────────────
const double HEX_SIZE_KM = 1.0;
const int TOTAL_FRANCE_HEXES = 550000;

// ─── Colors ─────────────────────────────────────────────────────────────────
const int kColorBackground = 0xFF0A0A0F;
const int kColorLockedHex = 0xFF1A1A2E;
const int kColorLockedHexBorder = 0xFF2A2A4E;
const int kColorUnlockedHex = 0xFF2D5016;
const int kColorFranceBorder = 0xFFE8C547;
const int kColorAccent = 0xFFE8C547;
const int kColorCorn = 0xFFF5C518;
const int kColorHusker = 0xFFCC0000;
const int kColorFriendHex = 0x551A3A6E;

// Group member color palette (up to 8 members)
const List<int> kGroupMemberColors = [
  0x552D5016, // self - green
  0x551A3A6E, // friend 1 - blue
  0x557A1F2D, // friend 2 - red
  0x556B4F12, // friend 3 - amber
  0x55284B5A, // friend 4 - teal
  0x554A1F6B, // friend 5 - purple
  0x555A2D1A, // friend 6 - brown
  0x551A4A3E, // friend 7 - emerald
];

// ─── Trip ───────────────────────────────────────────────────────────────────
const int kMaxUnlockedCellsPerDoc = 10000;
const int kSyncDebounceSeconds = 30;
const int kDwellSecondsRequired = 30;
const double kDistanceFilterMeters = 50.0;
const int kMaxVisibleHexes = 500;
const double kViewportPaddingDeg = 0.5;

// ─── Invite Code ────────────────────────────────────────────────────────────
const String kInviteCodeChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const int kInviteCodeLength = 6;

String generateInviteCode() {
  final random = Random.secure();
  return List.generate(
    kInviteCodeLength,
    (_) => kInviteCodeChars[random.nextInt(kInviteCodeChars.length)],
  ).join();
}

// ─── Avatar Emojis ──────────────────────────────────────────────────────────
const List<String> kAvatarEmojis = [
  '🌽', '🦅', '🗼', '🍷', '🧀', '🥐', '🌸', '🏰',
  '⚜️', '🎭', '🚀', '🌊', '🦁', '🌙', '⭐', '🎨',
];

// ─── Map Tiles (CartoDB — free, no API key, no credit card) ─────────────────
/// CartoDB Dark Matter tile URL. Subdomains a/b/c/d rotate automatically.
const String kTileUrlTemplate =
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
const List<String> kTileSubdomains = ['a', 'b', 'c', 'd'];
const String kTileAttribution =
    '© OpenStreetMap contributors, © CARTO';

const double kFranceCenterLat = 46.2276;
const double kFranceCenterLng = 2.2137;
const double kInitialZoom = 5.5;
const int kMaxTileZoom = 19;
