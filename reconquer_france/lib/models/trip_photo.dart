import 'package:hive_flutter/hive_flutter.dart';

part 'trip_photo.g.dart';

@HiveType(typeId: 1)
class TripPhoto extends HiveObject {
  @HiveField(0)
  final String id; // UUID

  @HiveField(1)
  final String assetId; // device photo library ID

  @HiveField(2)
  final String localPath; // local file path

  @HiveField(3)
  final String hexId; // "col:row"

  @HiveField(4)
  final double lat;

  @HiveField(5)
  final double lng;

  @HiveField(6)
  final DateTime takenAt;

  @HiveField(7)
  final String tripId;

  @HiveField(8)
  final String? thumbnailBase64; // 50x50 for Firestore social

  @HiveField(9)
  final bool isSynced;

  @HiveField(10)
  final String? cityName; // reverse geocoded

  TripPhoto({
    required this.id,
    required this.assetId,
    required this.localPath,
    required this.hexId,
    required this.lat,
    required this.lng,
    required this.takenAt,
    required this.tripId,
    this.thumbnailBase64,
    this.isSynced = false,
    this.cityName,
  });

  TripPhoto copyWith({
    String? thumbnailBase64,
    bool? isSynced,
    String? cityName,
  }) {
    return TripPhoto(
      id: id,
      assetId: assetId,
      localPath: localPath,
      hexId: hexId,
      lat: lat,
      lng: lng,
      takenAt: takenAt,
      tripId: tripId,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
      isSynced: isSynced ?? this.isSynced,
      cityName: cityName ?? this.cityName,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'assetId': assetId,
      'hexId': hexId,
      'lat': lat,
      'lng': lng,
      'takenAt': takenAt.toIso8601String(),
      'thumbnailBase64': thumbnailBase64,
      'cityName': cityName,
    };
  }

  Map<String, dynamic> toHiveMap() {
    return {
      'id': id,
      'assetId': assetId,
      'localPath': localPath,
      'hexId': hexId,
      'lat': lat,
      'lng': lng,
      'takenAt': takenAt.toIso8601String(),
      'tripId': tripId,
      'thumbnailBase64': thumbnailBase64,
      'isSynced': isSynced,
      'cityName': cityName,
    };
  }

  factory TripPhoto.fromHiveMap(Map<String, dynamic> map) {
    return TripPhoto(
      id: map['id'] as String,
      assetId: map['assetId'] as String,
      localPath: map['localPath'] as String,
      hexId: map['hexId'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      takenAt: DateTime.parse(map['takenAt'] as String),
      tripId: map['tripId'] as String,
      thumbnailBase64: map['thumbnailBase64'] as String?,
      isSynced: map['isSynced'] as bool? ?? false,
      cityName: map['cityName'] as String?,
    );
  }
}
