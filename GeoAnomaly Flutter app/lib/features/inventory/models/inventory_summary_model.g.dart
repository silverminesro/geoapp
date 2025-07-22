// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_summary_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InventorySummary _$InventorySummaryFromJson(Map<String, dynamic> json) =>
    InventorySummary(
      totalItems: (json['total_items'] as num).toInt(),
      totalArtifacts: (json['total_artifacts'] as num).toInt(),
      totalGear: (json['total_gear'] as num).toInt(),
      totalValue: (json['total_value'] as num).toInt(),
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      rarityBreakdown: Map<String, int>.from(json['rarity_breakdown'] as Map),
      biomeBreakdown: Map<String, int>.from(json['biome_breakdown'] as Map),
    );

Map<String, dynamic> _$InventorySummaryToJson(InventorySummary instance) =>
    <String, dynamic>{
      'total_items': instance.totalItems,
      'total_artifacts': instance.totalArtifacts,
      'total_gear': instance.totalGear,
      'total_value': instance.totalValue,
      'last_updated': instance.lastUpdated.toIso8601String(),
      'rarity_breakdown': instance.rarityBreakdown,
      'biome_breakdown': instance.biomeBreakdown,
    };
