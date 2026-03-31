import 'package:flutter_test/flutter_test.dart';
import 'package:reconquer_france/core/constants.dart';

void main() {
  group('generateInviteCode', () {
    test('returns a string of exactly 6 characters', () {
      final code = generateInviteCode();
      expect(code.length, equals(kInviteCodeLength));
    });

    test('contains only uppercase letters and digits', () {
      for (int i = 0; i < 20; i++) {
        final code = generateInviteCode();
        expect(
          RegExp(r'^[A-Z0-9]+$').hasMatch(code),
          isTrue,
          reason: 'Code "$code" contains invalid characters',
        );
      }
    });

    test('generates different codes on subsequent calls', () {
      // Probability of collision is astronomically low (36^6 ≈ 2 billion combos)
      final codes = List.generate(10, (_) => generateInviteCode()).toSet();
      expect(codes.length, greaterThan(1));
    });
  });

  group('Constants', () {
    test('France bounding box is well-ordered', () {
      expect(FRANCE_NORTH, greaterThan(FRANCE_SOUTH));
      expect(FRANCE_EAST, greaterThan(FRANCE_WEST));
    });

    test('Lincoln bounding box is well-ordered', () {
      expect(LINCOLN_NORTH, greaterThan(LINCOLN_SOUTH));
      expect(LINCOLN_EAST, greaterThan(LINCOLN_WEST));
    });

    test('Lincoln center is within Lincoln bounding box', () {
      expect(LINCOLN_CENTER_LAT, greaterThanOrEqualTo(LINCOLN_SOUTH));
      expect(LINCOLN_CENTER_LAT, lessThanOrEqualTo(LINCOLN_NORTH));
      expect(LINCOLN_CENTER_LNG, greaterThanOrEqualTo(LINCOLN_WEST));
      expect(LINCOLN_CENTER_LNG, lessThanOrEqualTo(LINCOLN_EAST));
    });

    test('Lincoln bounding box does not overlap with France', () {
      // Lincoln is in the US; France is in Europe — no lat/lng overlap
      final lincolnOverlapsFranceLat =
          LINCOLN_NORTH >= FRANCE_SOUTH && LINCOLN_SOUTH <= FRANCE_NORTH;
      final lincolnOverlapsFranceLng =
          LINCOLN_EAST >= FRANCE_WEST && LINCOLN_WEST <= FRANCE_EAST;
      expect(lincolnOverlapsFranceLat && lincolnOverlapsFranceLng, isFalse);
    });

    test('kMaxUnlockedCellsPerDoc is positive', () {
      expect(kMaxUnlockedCellsPerDoc, greaterThan(0));
    });

    test('kAvatarEmojis is not empty', () {
      expect(kAvatarEmojis, isNotEmpty);
    });

    test('kGroupMemberColors has 8 entries', () {
      expect(kGroupMemberColors.length, equals(8));
    });
  });
}
