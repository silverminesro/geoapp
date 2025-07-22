// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gear_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GearItem _$GearItemFromJson(Map<String, dynamic> json) => GearItem(
      id: json['id'] as String,
      zoneId: json['zone_id'] as String?,
      name: json['name'] as String,
      type: json['type'] as String,
      level: (json['level'] as num).toInt(),
      locationLatitude: (json['location_latitude'] as num?)?.toDouble(),
      locationLongitude: (json['location_longitude'] as num?)?.toDouble(),
      locationTimestamp: json['location_timestamp'] == null
          ? null
          : DateTime.parse(json['location_timestamp'] as String),
      properties: json['properties'] as Map<String, dynamic>,
      isActive: json['is_active'] as bool,
      biome: json['biome'] as String?,
      exclusiveToBiome: json['exclusive_to_biome'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
    );

Map<String, dynamic> _$GearItemToJson(GearItem instance) => <String, dynamic>{
      'id': instance.id,
      'zone_id': instance.zoneId,
      'name': instance.name,
      'type': instance.type,
      'level': instance.level,
      'location_latitude': instance.locationLatitude,
      'location_longitude': instance.locationLongitude,
      'location_timestamp': instance.locationTimestamp?.toIso8601String(),
      'properties': instance.properties,
      'is_active': instance.isActive,
      'biome': instance.biome,
      'exclusive_to_biome': instance.exclusiveToBiome,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'deleted_at': instance.deletedAt?.toIso8601String(),
    };
