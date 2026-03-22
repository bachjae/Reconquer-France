import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/hex_grid_service.dart';

/// CustomPainter for rendering hex grid overlay on canvas
/// Used for the export card and any non-Mapbox hex rendering.
class HexOverlayPainter extends CustomPainter {
  final Set<String> unlockedCells;
  final Map<String, Set<String>> friendCells; // uid -> cells
  final double northLat;
  final double southLat;
  final double westLng;
  final double eastLng;

  const HexOverlayPainter({
    required this.unlockedCells,
    this.friendCells = const {},
    this.northLat = FRANCE_NORTH,
    this.southLat = FRANCE_SOUTH,
    this.westLng = FRANCE_WEST,
    this.eastLng = FRANCE_EAST,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lockedPaint = Paint()
      ..color = const Color(kColorLockedHex).withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final lockedBorderPaint = Paint()
      ..color = const Color(kColorLockedHexBorder)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;

    final unlockedPaint = Paint()
      ..color = const Color(kColorUnlockedHex).withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final unlockedBorderPaint = Paint()
      ..color = const Color(kColorAccent).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Get visible hex IDs
    final hexIds = HexGridService.getHexIdsInBounds(
      northLat: northLat,
      southLat: southLat,
      westLng: westLng,
      eastLng: eastLng,
    ).take(kMaxVisibleHexes);

    for (final hexId in hexIds) {
      final corners = HexGridService.hexCorners(hexId);
      final path = _cornersToPath(corners, size);

      final isUnlocked = unlockedCells.contains(hexId);

      // Check friend ownership
      String? ownerUid;
      for (final entry in friendCells.entries) {
        if (entry.value.contains(hexId)) {
          ownerUid = entry.key;
          break;
        }
      }

      if (isUnlocked) {
        canvas.drawPath(path, unlockedPaint);
        canvas.drawPath(path, unlockedBorderPaint);
      } else if (ownerUid != null) {
        final friendPaint = Paint()
          ..color = const Color(kColorFriendHex)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, friendPaint);
      } else {
        canvas.drawPath(path, lockedPaint);
        canvas.drawPath(path, lockedBorderPaint);
      }
    }
  }

  Path _cornersToPath(List<LatLng> corners, Size size) {
    final path = Path();
    for (int i = 0; i < corners.length; i++) {
      final x = _lngToX(corners[i].longitude, size.width);
      final y = _latToY(corners[i].latitude, size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  double _lngToX(double lng, double width) {
    return ((lng - westLng) / (eastLng - westLng)) * width;
  }

  double _latToY(double lat, double height) {
    return (1 - (lat - southLat) / (northLat - southLat)) * height;
  }

  @override
  bool shouldRepaint(HexOverlayPainter old) {
    return old.unlockedCells.length != unlockedCells.length ||
        old.friendCells.length != friendCells.length;
  }
}

/// Widget that wraps HexOverlayPainter with friend overlay
class FriendMapOverlay extends StatelessWidget {
  final Set<String> unlockedCells;
  final Map<String, Set<String>> friendCells;

  const FriendMapOverlay({
    required this.unlockedCells,
    required this.friendCells,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: HexOverlayPainter(
        unlockedCells: unlockedCells,
        friendCells: friendCells,
      ),
    );
  }
}
