import 'package:hive_flutter/hive_flutter.dart';

part 'hex_cell.g.dart';

@HiveType(typeId: 0)
class HexCell extends HiveObject {
  @HiveField(0)
  final String id; // "col:row"

  @HiveField(1)
  final bool isUnlocked;

  @HiveField(2)
  final DateTime? unlockedAt;

  @HiveField(3)
  final List<String> photoIds; // local asset IDs

  @HiveField(4)
  final String? coverPhotoId;

  @HiveField(5)
  final String? unlockedByUid; // uid of who unlocked (for group maps)

  HexCell({
    required this.id,
    this.isUnlocked = false,
    this.unlockedAt,
    this.photoIds = const [],
    this.coverPhotoId,
    this.unlockedByUid,
  });

  HexCell copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    List<String>? photoIds,
    String? coverPhotoId,
    String? unlockedByUid,
  }) {
    return HexCell(
      id: id,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      photoIds: photoIds ?? this.photoIds,
      coverPhotoId: coverPhotoId ?? this.coverPhotoId,
      unlockedByUid: unlockedByUid ?? this.unlockedByUid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'photoIds': photoIds,
      'coverPhotoId': coverPhotoId,
      'unlockedByUid': unlockedByUid,
    };
  }

  factory HexCell.fromMap(Map<String, dynamic> map) {
    return HexCell(
      id: map['id'] as String,
      isUnlocked: map['isUnlocked'] as bool? ?? false,
      unlockedAt: map['unlockedAt'] != null
          ? DateTime.parse(map['unlockedAt'] as String)
          : null,
      photoIds: List<String>.from(map['photoIds'] as List? ?? []),
      coverPhotoId: map['coverPhotoId'] as String?,
      unlockedByUid: map['unlockedByUid'] as String?,
    );
  }
}
