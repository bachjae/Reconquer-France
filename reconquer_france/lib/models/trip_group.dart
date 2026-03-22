import 'package:cloud_firestore/cloud_firestore.dart';

class TripGroup {
  final String id;
  final String name;
  final String createdBy;
  final List<String> memberIds;
  final String? tripId;
  final String inviteCode;
  final DateTime createdAt;

  const TripGroup({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberIds,
    this.tripId,
    required this.inviteCode,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'createdBy': createdBy,
      'memberIds': memberIds,
      'tripId': tripId,
      'inviteCode': inviteCode,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TripGroup.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return TripGroup(
      id: doc.id,
      name: data['name'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      memberIds: List<String>.from(data['memberIds'] as List? ?? []),
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
