// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InventoryItem _$InventoryItemFromJson(Map<String, dynamic> json) =>
    InventoryItem(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      itemType: json['item_type'] as String,
      name: json['name'] as String,
      rarity: json['rarity'] as String,
      quantity: (json['quantity'] as num).toInt(),
      acquiredAt: DateTime.parse(json['acquired_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      userId: json['user_id'] as String?,
      properties: json['properties'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      discoveryLocation: json['discovery_location'] == null
          ? null
          : LocationModel.fromJson(
              json['discovery_location'] as Map<String, dynamic>),
      locationTimestamp: json['location_timestamp'] == null
          ? null
          : DateTime.parse(json['location_timestamp'] as String),
      isFavorite: json['is_favorite'] as bool? ?? false,
    );

Map<String, dynamic> _$InventoryItemToJson(InventoryItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'item_id': instance.itemId,
      'item_type': instance.itemType,
      'name': instance.name,
      'rarity': instance.rarity,
      'quantity': instance.quantity,
      'acquired_at': instance.acquiredAt.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'user_id': instance.userId,
      'properties': instance.properties,
      'discovery_location': instance.discoveryLocation,
      'location_timestamp': instance.locationTimestamp?.toIso8601String(),
      'is_favorite': instance.isFavorite,
    };
