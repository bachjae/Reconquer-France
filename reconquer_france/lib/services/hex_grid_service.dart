import 'dart:math';
import '../core/constants.dart';

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

class HexGridService {
  static const double hexSizeKm = HEX_SIZE_KM;
  static const double kmPerDegreeLat = 111.0;

  /// Convert lat/lng to hex cell ID string "col:row"
  static String latLngToHexId(double lat, double lng) {
    final double kmPerDegreeLng = kmPerDegreeLat * cos(lat * pi / 180);
    final double hexWidthDeg = (hexSizeKm * sqrt(3)) / kmPerDegreeLng;
    // Pointy-top hex row spacing = 1.5 * circumradius
    final double hexHeightDeg = (hexSizeKm * 1.5) / kmPerDegreeLat;

    int row = (lat / hexHeightDeg).floor();
    int col = (lng / hexWidthDeg).floor();

    // Offset for pointy-top hex (odd rows shift right by half hex width)
    if (row.isOdd) {
      col = ((lng - hexWidthDeg / 2) / hexWidthDeg).floor();
    }

    return '$col:$row';
  }

  /// Get hex center lat/lng from ID
  static LatLng hexIdToCenter(String hexId) {
    final parts = hexId.split(':');
    final int col = int.parse(parts[0]);
    final int row = int.parse(parts[1]);

    final double lat = (row + 0.5) * (hexSizeKm * 1.5 / kmPerDegreeLat);
    final double kmPerDegreeLng = kmPerDegreeLat * cos(lat * pi / 180);
    final double hexWidthDeg = (hexSizeKm * sqrt(3)) / kmPerDegreeLng;

    double lng = (col + 0.5) * hexWidthDeg;
    if (row.isOdd) lng += hexWidthDeg / 2;

    return LatLng(lat, lng);
  }

  /// Get 6 corner points of a hex for rendering (pointy-top orientation).
  /// R_lat and R_lng are sized so hexes tile with zero gap.
  static List<LatLng> hexCorners(String hexId) {
    final LatLng center = hexIdToCenter(hexId);
    final double lat = center.latitude;
    final double kmPerDegreeLng = kmPerDegreeLat * cos(lat * pi / 180);

    // Circumradius = hexSizeKm for both axes so hexes are regular (no gaps).
    //   Column spacing = R * sqrt(3) = hexWidthDeg  → R_lng = hexSizeKm / kmPerDegreeLng ✓
    //   Row spacing    = R * 1.5     = hexHeightDeg → R_lat = hexSizeKm / kmPerDegreeLat ✓
    final double R_lat = hexSizeKm / kmPerDegreeLat;
    final double R_lng = hexSizeKm / kmPerDegreeLng;

    final List<LatLng> corners = [];
    for (int i = 0; i < 6; i++) {
      // Pointy-top: angles at -30°, 30°, 90°, 150°, 210°, 270°
      final double angleDeg = 60.0 * i - 30.0;
      final double angleRad = angleDeg * pi / 180;
      corners.add(LatLng(
        center.latitude - R_lat * sin(angleRad),
        center.longitude + R_lng * cos(angleRad),
      ));
    }
    return corners;
  }

  /// Get all hex IDs within a bounding box (with padding)
  static List<String> getHexIdsInBounds({
    required double northLat,
    required double southLat,
    required double westLng,
    required double eastLng,
    double paddingDeg = 0.0,
  }) {
    final double padN = northLat + paddingDeg;
    final double padS = southLat - paddingDeg;
    final double padW = westLng - paddingDeg;
    final double padE = eastLng + paddingDeg;

    // Estimate row range
    final double hexHeightDeg = hexSizeKm * 1.5 / kmPerDegreeLat;
    final int rowMin = (padS / hexHeightDeg).floor();
    final int rowMax = (padN / hexHeightDeg).ceil();

    final List<String> hexIds = [];

    for (int row = rowMin; row <= rowMax; row++) {
      final double lat = (row + 0.5) * hexHeightDeg;
      final double kmPerDegreeLng = kmPerDegreeLat * cos(lat * pi / 180);
      final double hexWidthDeg = (hexSizeKm * sqrt(3)) / kmPerDegreeLng;

      // Estimate col range for this row
      final int colMin = (padW / hexWidthDeg).floor() - 1;
      final int colMax = (padE / hexWidthDeg).ceil() + 1;

      for (int col = colMin; col <= colMax; col++) {
        // Verify center is within bounds
        double lng = (col + 0.5) * hexWidthDeg;
        if (row.isOdd) lng += hexWidthDeg / 2;

        if (lat >= padS && lat <= padN && lng >= padW && lng <= padE) {
          hexIds.add('$col:$row');
        }
      }
    }

    return hexIds;
  }

  /// Convert hex corners to GeoJSON polygon coordinate array
  static List<List<double>> hexCornersToGeoJson(String hexId) {
    final corners = hexCorners(hexId);
    final coords = corners
        .map((c) => [c.longitude, c.latitude])
        .toList();
    // Close the polygon
    coords.add(coords.first);
    return coords;
  }

  /// Get neighboring hex IDs (6 neighbors)
  static List<String> getNeighbors(String hexId) {
    final parts = hexId.split(':');
    final int col = int.parse(parts[0]);
    final int row = int.parse(parts[1]);

    // Offset hex grid neighbors
    final List<List<int>> evenRowNeighbors = [
      [col + 1, row], [col - 1, row],
      [col, row + 1], [col, row - 1],
      [col - 1, row + 1], [col - 1, row - 1],
    ];
    final List<List<int>> oddRowNeighbors = [
      [col + 1, row], [col - 1, row],
      [col, row + 1], [col, row - 1],
      [col + 1, row + 1], [col + 1, row - 1],
    ];

    final neighbors = row.isOdd ? oddRowNeighbors : evenRowNeighbors;
    return neighbors.map((n) => '${n[0]}:${n[1]}').toList();
  }

  /// Check if a lat/lng is within France's bounding box
  static bool isInFrance(double lat, double lng) {
    return lat >= FRANCE_SOUTH &&
        lat <= FRANCE_NORTH &&
        lng >= FRANCE_WEST &&
        lng <= FRANCE_EAST;
  }

  /// Check if a lat/lng is within Lincoln NE test area
  static bool isInLincoln(double lat, double lng) {
    return lat >= LINCOLN_SOUTH &&
        lat <= LINCOLN_NORTH &&
        lng >= LINCOLN_WEST &&
        lng <= LINCOLN_EAST;
  }

  /// Check if a lat/lng is in an active unlockable area (France or Lincoln in test mode)
  static bool isInActiveArea(double lat, double lng, {bool testMode = false}) {
    return isInFrance(lat, lng) || (testMode && isInLincoln(lat, lng));
  }
}
