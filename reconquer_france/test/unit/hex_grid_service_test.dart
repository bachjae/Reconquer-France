import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconquer_france/services/hex_grid_service.dart';
import 'package:reconquer_france/core/constants.dart';

void main() {
  group('HexGridService', () {
    // ── latLngToHexId / hexIdToCenter round-trip ──────────────────────────

    test('latLngToHexId returns non-empty id for valid France coords', () {
      final id = HexGridService.latLngToHexId(48.8566, 2.3522); // Paris
      expect(id, isNotEmpty);
      expect(id.contains(':'), isTrue);
    });

    test('hexId round-trip: center of id maps back to same id', () {
      const lat = 48.8566;
      const lng = 2.3522;
      final id = HexGridService.latLngToHexId(lat, lng);
      final center = HexGridService.hexIdToCenter(id);
      final roundTripped = HexGridService.latLngToHexId(
          center.latitude, center.longitude);
      expect(roundTripped, equals(id));
    });

    test('different nearby points may map to different hex ids', () {
      // 2 km apart — should not always be the same cell
      final id1 = HexGridService.latLngToHexId(48.8566, 2.3522);
      final id2 = HexGridService.latLngToHexId(48.875, 2.375);
      // At least one should exist; we just verify they are valid strings
      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);
    });

    // ── hexCorners ────────────────────────────────────────────────────────

    test('hexCorners returns exactly 6 corners', () {
      final id = HexGridService.latLngToHexId(48.8566, 2.3522);
      final corners = HexGridService.hexCorners(id);
      expect(corners.length, equals(6));
    });

    test('hexCorners are close to center (within ~2 km)', () {
      final id = HexGridService.latLngToHexId(48.8566, 2.3522);
      final center = HexGridService.hexIdToCenter(id);
      final corners = HexGridService.hexCorners(id);
      for (final corner in corners) {
        final latDiff = (corner.latitude - center.latitude).abs() * 111.0;
        final lngDiff = (corner.longitude - center.longitude).abs() *
            111.0 * cos(center.latitude * pi / 180);
        final distKm = sqrt(latDiff * latDiff + lngDiff * lngDiff);
        expect(distKm, lessThan(2.0),
            reason: 'Corner $corner is too far from center $center');
      }
    });

    // ── isInFrance ────────────────────────────────────────────────────────

    test('isInFrance returns true for Paris', () {
      expect(HexGridService.isInFrance(48.8566, 2.3522), isTrue);
    });

    test('isInFrance returns true for Marseille', () {
      expect(HexGridService.isInFrance(43.2965, 5.3698), isTrue);
    });

    test('isInFrance returns false for London', () {
      expect(HexGridService.isInFrance(51.5074, -0.1278), isFalse);
    });

    test('isInFrance returns false for Berlin', () {
      expect(HexGridService.isInFrance(52.52, 13.405), isFalse);
    });

    test('isInFrance returns false for New York', () {
      expect(HexGridService.isInFrance(40.7128, -74.006), isFalse);
    });

    test('isInFrance uses correct bounding box boundaries', () {
      expect(HexGridService.isInFrance(FRANCE_NORTH, FRANCE_WEST), isTrue);
      expect(HexGridService.isInFrance(FRANCE_SOUTH, FRANCE_EAST), isTrue);
      expect(
          HexGridService.isInFrance(FRANCE_NORTH + 0.01, FRANCE_WEST),
          isFalse);
      expect(
          HexGridService.isInFrance(FRANCE_SOUTH - 0.01, FRANCE_EAST),
          isFalse);
    });

    // ── isInLincoln ───────────────────────────────────────────────────────

    test('isInLincoln returns true for Lincoln NE center', () {
      expect(
          HexGridService.isInLincoln(
              LINCOLN_CENTER_LAT, LINCOLN_CENTER_LNG),
          isTrue);
    });

    test('isInLincoln returns false for Paris', () {
      expect(HexGridService.isInLincoln(48.8566, 2.3522), isFalse);
    });

    // ── isInActiveArea ────────────────────────────────────────────────────

    test('isInActiveArea includes France regardless of testMode', () {
      expect(
          HexGridService.isInActiveArea(48.8566, 2.3522, testMode: false),
          isTrue);
      expect(
          HexGridService.isInActiveArea(48.8566, 2.3522, testMode: true),
          isTrue);
    });

    test('isInActiveArea excludes Lincoln when testMode=false', () {
      expect(
          HexGridService.isInActiveArea(
              LINCOLN_CENTER_LAT, LINCOLN_CENTER_LNG,
              testMode: false),
          isFalse);
    });

    test('isInActiveArea includes Lincoln when testMode=true', () {
      expect(
          HexGridService.isInActiveArea(
              LINCOLN_CENTER_LAT, LINCOLN_CENTER_LNG,
              testMode: true),
          isTrue);
    });

    test('isInActiveArea excludes random US location in both modes', () {
      // Omaha NE — outside Lincoln bounding box
      const omahaLat = 41.2565;
      const omahaLng = -95.9345;
      expect(
          HexGridService.isInActiveArea(omahaLat, omahaLng, testMode: false),
          isFalse);
      expect(
          HexGridService.isInActiveArea(omahaLat, omahaLng, testMode: true),
          isFalse);
    });

    // ── getNeighbors ──────────────────────────────────────────────────────

    test('getNeighbors returns exactly 6 neighbors', () {
      final id = HexGridService.latLngToHexId(48.8566, 2.3522);
      final neighbors = HexGridService.getNeighbors(id);
      expect(neighbors.length, equals(6));
    });

    test('getNeighbors does not include self', () {
      final id = HexGridService.latLngToHexId(48.8566, 2.3522);
      final neighbors = HexGridService.getNeighbors(id);
      expect(neighbors.contains(id), isFalse);
    });

    test('getNeighbors returns valid hex id format', () {
      final id = HexGridService.latLngToHexId(48.8566, 2.3522);
      final neighbors = HexGridService.getNeighbors(id);
      for (final n in neighbors) {
        expect(n.contains(':'), isTrue,
            reason: 'Neighbor $n is not in col:row format');
      }
    });

    // ── getHexIdsInBounds ─────────────────────────────────────────────────

    test('getHexIdsInBounds returns non-empty list for valid box', () {
      final ids = HexGridService.getHexIdsInBounds(
        northLat: 48.9,
        southLat: 48.8,
        westLng: 2.3,
        eastLng: 2.4,
      );
      expect(ids, isNotEmpty);
    });

    test('getHexIdsInBounds all returned ids are in col:row format', () {
      final ids = HexGridService.getHexIdsInBounds(
        northLat: 48.9,
        southLat: 48.8,
        westLng: 2.3,
        eastLng: 2.4,
      );
      for (final id in ids) {
        expect(id.contains(':'), isTrue);
        final parts = id.split(':');
        expect(parts.length, equals(2));
        expect(() => int.parse(parts[0]), returnsNormally);
        expect(() => int.parse(parts[1]), returnsNormally);
      }
    });

    test('getHexIdsInBounds returns empty for invalid/inverted bounds', () {
      final ids = HexGridService.getHexIdsInBounds(
        northLat: 48.8,
        southLat: 48.9, // south > north — impossible
        westLng: 2.3,
        eastLng: 2.4,
      );
      expect(ids, isEmpty);
    });

    // ── hexCornersToGeoJson ───────────────────────────────────────────────

    test('hexCornersToGeoJson returns 7 coords (6 + close)', () {
      final id = HexGridService.latLngToHexId(48.8566, 2.3522);
      final coords = HexGridService.hexCornersToGeoJson(id);
      expect(coords.length, equals(7));
    });

    test('hexCornersToGeoJson first and last coord are equal (closed ring)', () {
      final id = HexGridService.latLngToHexId(48.8566, 2.3522);
      final coords = HexGridService.hexCornersToGeoJson(id);
      expect(coords.first, equals(coords.last));
    });
  });
}
