import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../core/models/zone_model.dart'; // Import pre Location

part 'artifact_item_model.g.dart';

@JsonSerializable()
class ArtifactItem extends Equatable {
  final String id;

  @JsonKey(name: 'zone_id')
  final String? zoneId;

  final String name;
  final String type; // crystal, orb, scroll, tablet, rune
  final String rarity; // rare, epic, legendary

  @JsonKey(name: 'location_latitude')
  final double? locationLatitude;

  @JsonKey(name: 'location_longitude')
  final double? locationLongitude;

  @JsonKey(name: 'location_timestamp')
  final DateTime? locationTimestamp;

  final Map<String, dynamic> properties;

  @JsonKey(name: 'is_active')
  final bool isActive;

  final String? biome; // wasteland, rocky, desert

  @JsonKey(name: 'exclusive_to_biome')
  final bool exclusiveToBiome;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @JsonKey(name: 'deleted_at')
  final DateTime? deletedAt;

  const ArtifactItem({
    required this.id,
    this.zoneId,
    required this.name,
    required this.type,
    required this.rarity,
    this.locationLatitude,
    this.locationLongitude,
    this.locationTimestamp,
    required this.properties,
    required this.isActive,
    this.biome,
    required this.exclusiveToBiome,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory ArtifactItem.fromJson(Map<String, dynamic> json) =>
      _$ArtifactItemFromJson(json);

  Map<String, dynamic> toJson() => _$ArtifactItemToJson(this);

  @override
  List<Object?> get props => [
        id,
        zoneId,
        name,
        type,
        rarity,
        locationLatitude,
        locationLongitude,
        locationTimestamp,
        properties,
        isActive,
        biome,
        exclusiveToBiome,
        createdAt,
        updatedAt,
        deletedAt,
      ];

  // Discovery location helpers
  bool get hasDiscoveryLocation =>
      locationLatitude != null && locationLongitude != null;

  Location? get discoveryLocation {
    if (!hasDiscoveryLocation) return null;
    return Location(
      latitude: locationLatitude!,
      longitude: locationLongitude!,
    );
  }

  // Rarity helpers
  Color get rarityColor {
    switch (rarity.toLowerCase()) {
      case 'rare':
        return const Color(0xFF2196F3); // Blue
      case 'epic':
        return const Color(0xFF9C27B0); // Purple
      case 'legendary':
        return const Color(0xFFFF9800); // Orange
      default:
        return Colors.grey;
    }
  }

  String get rarityEmoji {
    switch (rarity.toLowerCase()) {
      case 'rare':
        return '🔵';
      case 'epic':
        return '🟣';
      case 'legendary':
        return '🟠';
      default:
        return '⚪';
    }
  }

  String get rarityDisplayName {
    switch (rarity.toLowerCase()) {
      case 'rare':
        return 'Rare';
      case 'epic':
        return 'Epic';
      case 'legendary':
        return 'Legendary';
      default:
        return 'Common';
    }
  }

  // Type helpers
  String get typeIcon {
    switch (type.toLowerCase()) {
      case 'crystal':
        return '💎';
      case 'orb':
        return '🔮';
      case 'scroll':
        return '📜';
      case 'tablet':
        return '📱';
      case 'rune':
        return 'ᚱ';
      default:
        return '❓';
    }
  }

  String get typeDisplayName {
    switch (type.toLowerCase()) {
      case 'crystal':
        return 'Crystal';
      case 'orb':
        return 'Orb';
      case 'scroll':
        return 'Scroll';
      case 'tablet':
        return 'Tablet';
      case 'rune':
        return 'Rune';
      default:
        return type.toUpperCase();
    }
  }

  // Biome helpers
  String get biomeEmoji {
    switch (biome?.toLowerCase()) {
      case 'wasteland':
        return '☠️';
      case 'rocky':
        return '🗿';
      case 'desert':
        return '🏜️';
      case 'forest':
        return '🌲';
      case 'swamp':
        return '🐸';
      case 'volcanic':
        return '🌋';
      default:
        return '🌍';
    }
  }

  String get biomeDisplayName {
    if (biome == null) return 'Unknown';
    return biome!
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Color get biomeColor {
    switch (biome?.toLowerCase()) {
      case 'wasteland':
        return const Color(0xFF8B4513); // Dark red/brown
      case 'rocky':
        return const Color(0xFF808080); // Grey
      case 'desert':
        return const Color(0xFFF4A460); // Sandy brown
      case 'forest':
        return const Color(0xFF228B22); // Forest green
      case 'swamp':
        return const Color(0xFF556B2F); // Dark olive green
      case 'volcanic':
        return const Color(0xFFFF4500); // Orange red
      default:
        return Colors.grey;
    }
  }

  // Discovery time helpers
  String get discoveryTimeDisplay {
    if (locationTimestamp == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(locationTimestamp!);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just discovered';
    }
  }

  String get discoveryDateFormatted {
    if (locationTimestamp == null) return 'Unknown';

    final date = locationTimestamp!;
    return '${date.day}.${date.month}.${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Properties helpers
  T? getProperty<T>(String key) {
    return properties[key] as T?;
  }

  String? get description => getProperty<String>('description');
  double? get value => getProperty<double>('value');
  int? get power => getProperty<int>('power');

  // Status helpers
  bool get isDeleted => deletedAt != null;
  bool get isAvailable => isActive && !isDeleted;

  // Copy with method
  ArtifactItem copyWith({
    String? id,
    String? zoneId,
    String? name,
    String? type,
    String? rarity,
    double? locationLatitude,
    double? locationLongitude,
    DateTime? locationTimestamp,
    Map<String, dynamic>? properties,
    bool? isActive,
    String? biome,
    bool? exclusiveToBiome,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ArtifactItem(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      name: name ?? this.name,
      type: type ?? this.type,
      rarity: rarity ?? this.rarity,
      locationLatitude: locationLatitude ?? this.locationLatitude,
      locationLongitude: locationLongitude ?? this.locationLongitude,
      locationTimestamp: locationTimestamp ?? this.locationTimestamp,
      properties: properties ?? this.properties,
      isActive: isActive ?? this.isActive,
      biome: biome ?? this.biome,
      exclusiveToBiome: exclusiveToBiome ?? this.exclusiveToBiome,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  String toString() {
    return 'ArtifactItem(id: $id, name: $name, type: $type, rarity: $rarity, biome: $biome)';
  }
}
