import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupMemberRole { leader, student }

class TripGroup {
  final String id;
  final String name;
  final String createdBy;
  final List<String> memberIds;
  final Map<String, String> roles; // uid -> 'leader' | 'student'
  final String? tripId;
  final String inviteCode;
  final DateTime createdAt;

  const TripGroup({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberIds,
    required this.roles,
    this.tripId,
    required this.inviteCode,
    required this.createdAt,
  });

  /// Role of a specific member. Creator always treated as leader.
  GroupMemberRole roleOf(String uid) {
    if (uid == createdBy) return GroupMemberRole.leader;
    return roles[uid] == 'leader'
        ? GroupMemberRole.leader
        : GroupMemberRole.student;
  }

  /// UIDs of all members with the leader role.
  List<String> get leaderIds => memberIds
      .where((uid) => roleOf(uid) == GroupMemberRole.leader)
      .toList();

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'createdBy': createdBy,
      'memberIds': memberIds,
      'roles': roles,
      'tripId': tripId,
      'inviteCode': inviteCode,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TripGroup.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawRoles = data['roles'] as Map<String, dynamic>? ?? {};
    return TripGroup(
      id: doc.id,
      name: data['name'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      memberIds: List<String>.from(data['memberIds'] as List? ?? []),
      roles: rawRoles.map((k, v) => MapEntry(k, (v as String?) ?? 'student')),
      tripId: data['tripId'] as String?,
      inviteCode: data['inviteCode'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class GroupAlert {
  final String id;
  final AlertType type;
  final String sentBy;
  final String senderName;
  final double lat;
  final double lng;
  final String message;
  final DateTime timestamp;
  final DateTime? resolvedAt;
  /// 'leaders_only' — only group leaders receive this alert.
  /// 'all' — every group member receives it.
  final String recipientType;

  const GroupAlert({
    required this.id,
    required this.type,
    required this.sentBy,
    required this.senderName,
    required this.lat,
    required this.lng,
    required this.message,
    required this.timestamp,
    this.resolvedAt,
    this.recipientType = 'leaders_only',
  });

  bool get isResolved => resolvedAt != null;

  factory GroupAlert.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return GroupAlert(
      id: doc.id,
      type: data['type'] == 'husker' ? AlertType.husker : AlertType.corn,
      sentBy: data['sentBy'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      message: data['message'] as String? ?? '',
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      recipientType:
          data['recipientType'] as String? ?? 'leaders_only',
    );
  }
}

enum AlertType { corn, husker }

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUsername;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUsername,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return FriendRequest(
      id: doc.id,
      fromUid: data['fromUid'] as String? ?? '',
      toUsername: data['toUsername'] as String? ?? '',
      status: _parseStatus(data['status'] as String?),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static FriendRequestStatus _parseStatus(String? s) {
    switch (s) {
      case 'accepted':
        return FriendRequestStatus.accepted;
      case 'declined':
        return FriendRequestStatus.declined;
      default:
        return FriendRequestStatus.pending;
    }
  }
}

enum FriendRequestStatus { pending, accepted, declined }
