import 'package:flutter_test/flutter_test.dart';

/// Tests for the sync queue entry parsing logic isolated from Hive/Firebase.
/// These verify the type-guard fix (is! String checks) and num-to-int cast.
void main() {
  group('Sync queue entry type-guard logic', () {
    /// Mirrors the corrected _flushQueue entry parsing logic.
    List<MapEntry<String, String>> _parseEntries(List<dynamic> entries) {
      final result = <MapEntry<String, String>>[];
      for (final entry in entries) {
        if (entry['type'] == 'unlock_cell') {
          final tripId = entry['tripId'];
          final hexId = entry['hexId'];
          if (tripId is! String || hexId is! String) continue;
          result.add(MapEntry(tripId, hexId));
        }
      }
      return result;
    }

    test('valid entries are parsed correctly', () {
      final entries = [
        {'type': 'unlock_cell', 'tripId': 'trip1', 'hexId': '100:200'},
        {'type': 'unlock_cell', 'tripId': 'trip1', 'hexId': '101:200'},
      ];
      final parsed = _parseEntries(entries);
      expect(parsed.length, equals(2));
      expect(parsed[0].value, equals('100:200'));
      expect(parsed[1].value, equals('101:200'));
    });

    test('entry with null tripId is skipped', () {
      final entries = [
        {'type': 'unlock_cell', 'tripId': null, 'hexId': '100:200'},
        {'type': 'unlock_cell', 'tripId': 'trip1', 'hexId': '101:200'},
      ];
      final parsed = _parseEntries(entries);
      expect(parsed.length, equals(1));
      expect(parsed[0].value, equals('101:200'));
    });

    test('entry with null hexId is skipped', () {
      final entries = [
        {'type': 'unlock_cell', 'tripId': 'trip1', 'hexId': null},
      ];
      final parsed = _parseEntries(entries);
      expect(parsed, isEmpty);
    });

    test('entry with non-String tripId is skipped', () {
      final entries = [
        {'type': 'unlock_cell', 'tripId': 42, 'hexId': '100:200'},
      ];
      final parsed = _parseEntries(entries);
      expect(parsed, isEmpty);
    });

    test('entries of other types are skipped', () {
      final entries = [
        {'type': 'other_action', 'tripId': 'trip1', 'hexId': '100:200'},
      ];
      final parsed = _parseEntries(entries);
      expect(parsed, isEmpty);
    });

    test('empty queue returns empty result', () {
      expect(_parseEntries([]), isEmpty);
    });
  });

  group('totalCellsUnlocked num-to-int cast', () {
    /// Mirrors the corrected cast: (value as num?)?.toInt() ?? 0
    int _parseCellCount(dynamic value) =>
        (value as num?)?.toInt() ?? 0;

    test('int value parses correctly', () {
      expect(_parseCellCount(500), equals(500));
    });

    test('double value converts to int via toInt()', () {
      expect(_parseCellCount(500.0), equals(500));
    });

    test('null returns 0', () {
      expect(_parseCellCount(null), equals(0));
    });

    test('large int value is preserved', () {
      expect(_parseCellCount(10000), equals(10000));
    });
  });
}
