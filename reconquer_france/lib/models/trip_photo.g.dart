// GENERATED CODE - DO NOT MODIFY BY HAND
// Run: flutter pub run build_runner build

part of 'trip_photo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripPhotoAdapter extends TypeAdapter<TripPhoto> {
  @override
  final int typeId = 1;

  @override
  TripPhoto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TripPhoto(
      id: fields[0] as String,
      assetId: fields[1] as String,
      localPath: fields[2] as String,
      hexId: fields[3] as String,
      lat: fields[4] as double,
      lng: fields[5] as double,
      takenAt: fields[6] as DateTime,
      tripId: fields[7] as String,
      thumbnailBase64: fields[8] as String?,
      isSynced: fields[9] as bool,
      cityName: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TripPhoto obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.assetId)
      ..writeByte(2)
      ..write(obj.localPath)
      ..writeByte(3)
      ..write(obj.hexId)
      ..writeByte(4)
      ..write(obj.lat)
      ..writeByte(5)
      ..write(obj.lng)
      ..writeByte(6)
      ..write(obj.takenAt)
      ..writeByte(7)
      ..write(obj.tripId)
      ..writeByte(8)
      ..write(obj.thumbnailBase64)
      ..writeByte(9)
      ..write(obj.isSynced)
      ..writeByte(10)
      ..write(obj.cityName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripPhotoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
