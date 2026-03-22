import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String username;
  final String avatarEmoji;
  final DateTime createdAt;
  final String? fcmToken;
  final List<String> friendIds;
  final String? activeTripId;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.avatarEmoji,
    required this.createdAt,
    this.fcmToken,
    this.friendIds = const [],
    this.activeTripId,
  });

  UserProfile copyWith({
    String? displayName,
    String? username,
    String? avatarEmoji,
    String? fcmToken,
    List<String>? friendIds,
    String? activeTripId,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      createdAt: createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
      friendIds: friendIds ?? this.friendIds,
      activeTripId: activeTripId ?? this.activeTripId,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'username': username,
      'avatarEmoji': avatarEmoji,
      'createdAt': Timestamp.fromDate(createdAt),
      'fcmToken': fcmToken,
      'friendIds': friendIds,
      'activeTripId': activeTripId,
    };
  }

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      username: data['username'] as String? ?? '',
      avatarEmoji: data['avatarEmoji'] as String? ?? '🌽',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmToken: data['fcmToken'] as String?,
      friendIds: List<String>.from(data['friendIds'] as List? ?? []),
      activeTripId: data['activeTripId'] as String?,
    );
  }
}

class Trip {
  final String id;
  final String name;
  final String uid;
  final String? groupId;
  final DateTime startDate;
  final DateTime? endDate;
  final List<String> unlockedCells;
  final int totalCellsUnlocked;
  final double percentFrance;

  const Trip({
    required this.id,
    required this.name,
    required this.uid,
    this.groupId,
    required this.startDate,
    this.endDate,
    this.unlockedCells = const [],
    this.totalCellsUnlocked = 0,
    this.percentFrance = 0.0,
  });

  double get computedPercent => (totalCellsUnlocked / 550000) * 100;

  Trip copyWith({
    String? name,
    String? groupId,
    DateTime? endDate,
    List<String>? unlockedCells,
    int? totalCellsUnlocked,
    double? percentFrance,
  }) {
    return Trip(
      id: id,
      name: name ?? this.name,
      uid: uid,
      groupId: groupId ?? this.groupId,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      unlockedCells: unlockedCells ?? this.unlockedCells,
      totalCellsUnlocked: totalCellsUnlocked ?? this.totalCellsUnlocked,
      percentFrance: percentFrance ?? this.percentFrance,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'uid': uid,
      'groupId': groupId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'unlockedCells': unlockedCells,
      'totalCellsUnlocked': totalCellsUnlocked,
      'percentFrance': percentFrance,
    };
  }

  factory Trip.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Trip(
      id: doc.id,
      name: data['name'] as String? ?? 'France Trip',
      uid: data['uid'] as String? ?? '',
      groupId: data['groupId'] as String?,
      startDate:
          (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      unlockedCells:
          List<String>.from(data['unlockedCells'] as List? ?? []),
      totalCellsUnlocked: data['totalCellsUnlocked'] as int? ?? 0,
      percentFrance: (data['percentFrance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
