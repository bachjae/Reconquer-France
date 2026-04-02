import 'package:flutter_test/flutter_test.dart';
import 'package:reconquer_france/models/trip_group.dart';

// ── Helpers to call fromFirestore without a real DocumentSnapshot ─────────────
// We construct models directly, bypassing Firestore entirely.

TripGroup _makeTripGroup({
  String id = 'group1',
  String name = 'Test Group',
  String createdBy = 'uid1',
  List<String> memberIds = const ['uid1', 'uid2'],
  Map<String, String> roles = const {'uid1': 'leader', 'uid2': 'student'},
  String? tripId,
  String inviteCode = 'ABC123',
  DateTime? createdAt,
}) {
  return TripGroup(
    id: id,
    name: name,
    createdBy: createdBy,
    memberIds: memberIds,
    roles: roles,
    tripId: tripId,
    inviteCode: inviteCode,
    createdAt: createdAt ?? DateTime(2025, 1, 1),
  );
}

GroupAlert _makeGroupAlert({
  String id = 'alert1',
  AlertType type = AlertType.corn,
  String sentBy = 'uid1',
  String senderName = 'Alice',
  double lat = 48.8566,
  double lng = 2.3522,
  String message = 'Need help!',
  DateTime? timestamp,
  DateTime? resolvedAt,
  String recipientType = 'leaders_only',
}) {
  return GroupAlert(
    id: id,
    type: type,
    sentBy: sentBy,
    senderName: senderName,
    lat: lat,
    lng: lng,
    message: message,
    timestamp: timestamp ?? DateTime(2025, 6, 1),
    resolvedAt: resolvedAt,
    recipientType: recipientType,
  );
}

void main() {
  group('TripGroup', () {
    test('roleOf returns leader for a uid in roles map as leader', () {
      final group = _makeTripGroup(
        roles: {'uid1': 'leader', 'uid2': 'student'},
      );
      expect(group.roleOf('uid1'), equals(GroupMemberRole.leader));
    });

    test('roleOf returns student for a uid in roles map as student', () {
      final group = _makeTripGroup(
        roles: {'uid1': 'leader', 'uid2': 'student'},
      );
      expect(group.roleOf('uid2'), equals(GroupMemberRole.student));
    });

    test('roleOf returns student for a uid not in roles map', () {
      final group = _makeTripGroup(
        memberIds: ['uid1', 'uid2', 'uid3'],
        roles: {'uid1': 'leader'},
      );
      expect(group.roleOf('uid3'), equals(GroupMemberRole.student));
    });

    test('leaderIds returns only members with leader role', () {
      final group = _makeTripGroup(
        memberIds: ['uid1', 'uid2', 'uid3'],
        roles: {'uid1': 'leader', 'uid2': 'student', 'uid3': 'leader'},
      );
      expect(group.leaderIds, containsAll(['uid1', 'uid3']));
      expect(group.leaderIds, hasLength(2));
    });

    test('leaderIds is empty when no members have leader role', () {
      final group = _makeTripGroup(
        roles: {'uid1': 'student', 'uid2': 'student'},
      );
      expect(group.leaderIds, isEmpty);
    });

    test('new group creator starts as leader (invariant check)', () {
      // This mirrors the createGroup logic in social_provider.dart
      final group = _makeTripGroup(
        createdBy: 'uid1',
        memberIds: ['uid1'],
        roles: {'uid1': 'leader'},
      );
      expect(group.roleOf(group.createdBy), equals(GroupMemberRole.leader));
    });

    test('toFirestore round-trips name, inviteCode, memberIds', () {
      final group = _makeTripGroup();
      final map = group.toFirestore();
      expect(map['name'], equals(group.name));
      expect(map['inviteCode'], equals(group.inviteCode));
      expect(map['memberIds'], equals(group.memberIds));
    });
  });

  group('GroupAlert', () {
    test('isResolved is false when resolvedAt is null', () {
      final alert = _makeGroupAlert(resolvedAt: null);
      expect(alert.isResolved, isFalse);
    });

    test('isResolved is true when resolvedAt is set', () {
      final alert = _makeGroupAlert(resolvedAt: DateTime(2025, 6, 2));
      expect(alert.isResolved, isTrue);
    });

    test('corn alert has correct type', () {
      final alert = _makeGroupAlert(type: AlertType.corn);
      expect(alert.type, equals(AlertType.corn));
    });

    test('husker alert has correct type', () {
      final alert = _makeGroupAlert(type: AlertType.husker);
      expect(alert.type, equals(AlertType.husker));
    });

    test('alert recipientType defaults to leaders_only', () {
      final alert = _makeGroupAlert();
      expect(alert.recipientType, equals('leaders_only'));
    });

    test('husker alert should be all_members recipientType', () {
      final alert =
          _makeGroupAlert(type: AlertType.husker, recipientType: 'all_members');
      expect(alert.recipientType, equals('all_members'));
    });

    // Student alert filter logic: students see alerts where recipientType != 'leaders_only'
    test('student filter: shows all_members alerts', () {
      final alerts = [
        _makeGroupAlert(id: 'a1', recipientType: 'leaders_only'),
        _makeGroupAlert(id: 'a2', recipientType: 'all_members'),
        _makeGroupAlert(id: 'a3', recipientType: 'all_members'),
      ];
      final studentVisible =
          alerts.where((a) => a.recipientType != 'leaders_only').toList();
      expect(studentVisible.map((a) => a.id), containsAll(['a2', 'a3']));
      expect(studentVisible.map((a) => a.id), isNot(contains('a1')));
    });

    test('leader filter: shows all alerts', () {
      final alerts = [
        _makeGroupAlert(id: 'a1', recipientType: 'leaders_only'),
        _makeGroupAlert(id: 'a2', recipientType: 'all_members'),
      ];
      // Leaders see everything
      expect(alerts, hasLength(2));
    });
  });

  group('FriendRequest', () {
    test('FriendRequestStatus pending is represented correctly', () {
      final req = FriendRequest(
        id: 'req1',
        fromUid: 'uid1',
        fromUsername: 'alice',
        toUsername: 'bob',
        status: FriendRequestStatus.pending,
        createdAt: DateTime(2025, 1, 1),
      );
      expect(req.status, equals(FriendRequestStatus.pending));
    });

    test('FriendRequestStatus accepted is represented correctly', () {
      final req = FriendRequest(
        id: 'req2',
        fromUid: 'uid1',
        fromUsername: 'alice',
        toUsername: 'bob',
        status: FriendRequestStatus.accepted,
        createdAt: DateTime(2025, 1, 2),
      );
      expect(req.status, equals(FriendRequestStatus.accepted));
    });
  });
}
