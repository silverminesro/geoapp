import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'inventory_summary_model.g.dart';

@JsonSerializable()
class InventorySummary extends Equatable {
  @JsonKey(name: 'total_items')
  final int totalItems;

  @JsonKey(name: 'total_artifacts')
  final int totalArtifacts;

  @JsonKey(name: 'total_gear')
  final int totalGear;

  @JsonKey(name: 'total_value')
  final int totalValue;

  @JsonKey(name: 'last_updated')
  final DateTime lastUpdated;

  @JsonKey(name: 'rarity_breakdown')
  final Map<String, int> rarityBreakdown;

  @JsonKey(name: 'biome_breakdown')
  final Map<String, int> biomeBreakdown;

  const InventorySummary({
    required this.totalItems,
    required this.totalArtifacts,
    required this.totalGear,
    required this.totalValue,
    required this.lastUpdated,
    required this.rarityBreakdown,
    required this.biomeBreakdown,
  });

  factory InventorySummary.fromJson(Map<String, dynamic> json) =>
      _$InventorySummaryFromJson(json);
  Map<String, dynamic> toJson() => _$InventorySummaryToJson(this);

  @override
  List<Object?> get props => [
        totalItems,
        totalArtifacts,
        totalGear,
        totalValue,
        lastUpdated,
        rarityBreakdown,
        biomeBreakdown,
      ];

  // Helper getters
  double get averageValue {
    return totalItems > 0 ? totalValue / totalItems : 0.0;
  }

  String get formattedTotalValue {
    if (totalValue >= 1000000) {
      return '${(totalValue / 1000000).toStringAsFixed(1)}M';
    } else if (totalValue >= 1000) {
      return '${(totalValue / 1000).toStringAsFixed(1)}K';
    } else {
      return totalValue.toString();
    }
  }

  // Get most common rarity
  String get mostCommonRarity {
    if (rarityBreakdown.isEmpty) return 'None';

    final sortedRarities = rarityBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedRarities.first.key;
  }

  // Get most common biome
  String get mostCommonBiome {
    if (biomeBreakdown.isEmpty) return 'None';

    final sortedBiomes = biomeBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedBiomes.first.key;
  }

  @override
  String toString() =>
      'InventorySummary(total: $totalItems, artifacts: $totalArtifacts, gear: $totalGear)';
}
