// GENERATED CODE - DO NOT MODIFY BY HAND
// Run: flutter pub run build_runner build

part of 'hex_cell.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HexCellAdapter extends TypeAdapter<HexCell> {
  @override
  final int typeId = 0;

  @override
  HexCell read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HexCell(
      id: fields[0] as String,
      isUnlocked: fields[1] as bool,
      unlockedAt: fields[2] as DateTime?,
      photoIds: (fields[3] as List).cast<String>(),
      coverPhotoId: fields[4] as String?,
      unlockedByUid: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HexCell obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.isUnlocked)
      ..writeByte(2)
      ..write(obj.unlockedAt)
      ..writeByte(3)
      ..write(obj.photoIds)
      ..writeByte(4)
      ..write(obj.coverPhotoId)
      ..writeByte(5)
      ..write(obj.unlockedByUid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HexCellAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
