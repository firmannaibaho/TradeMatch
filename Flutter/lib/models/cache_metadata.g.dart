// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_metadata.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CacheMetadataAdapter extends TypeAdapter<CacheMetadata> {
  @override
  final int typeId = 200;

  @override
  CacheMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CacheMetadata(
      key: fields[0] as String,
      cachedAt: fields[1] as DateTime,
      ttlSeconds: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CacheMetadata obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.key)
      ..writeByte(1)
      ..write(obj.cachedAt)
      ..writeByte(2)
      ..write(obj.ttlSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
