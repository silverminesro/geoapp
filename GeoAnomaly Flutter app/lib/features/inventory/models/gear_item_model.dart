import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../core/models/zone_model.dart'; // Import pre Location

part 'gear_item_model.g.dart';

@JsonSerializable()
class GearItem extends Equatable {
  final String id;

  @JsonKey(name: 'zone_id')
  final String? zoneId;

  final String name;
  final String type; // helmet, shield, armor, weapon, etc.
  final int level;

  @JsonKey(name: 'location_latitude')
  final double? locationLatitude;

  @JsonKey(name: 'location_longitude')
  final double? locationLongitude;

  @JsonKey(name: 'location_timestamp')
  final DateTime? locationTimestamp;

  final Map<String, dynamic> properties;

  @JsonKey(name: 'is_active')
  final bool isActive;

  final String? biome;

  @JsonKey(name: 'exclusive_to_biome')
  final bool exclusiveToBiome;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @JsonKey(name: 'deleted_at')
  final DateTime? deletedAt;

  const GearItem({
    required this.id,
    this.zoneId,
    required this.name,
    required this.type,
    required this.level,
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

  factory GearItem.fromJson(Map<String, dynamic> json) =>
      _$GearItemFromJson(json);

  Map<String, dynamic> toJson() => _$GearItemToJson(this);

  @override
  List<Object?> get props => [
        id,
        zoneId,
        name,
        type,
        level,
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

  // Level helpers
  Color get levelColor {
    if (level <= 1) return Colors.grey; // Basic
    if (level <= 3) return const Color(0xFF4CAF50); // Green
    if (level <= 5) return const Color(0xFF2196F3); // Blue
    if (level <= 7) return const Color(0xFF9C27B0); // Purple
    return const Color(0xFFFF9800); // Orange - Epic/Legendary
  }

  String get levelDisplayName {
    if (level <= 1) return 'Basic';
    if (level <= 3) return 'Common';
    if (level <= 5) return 'Rare';
    if (level <= 7) return 'Epic';
    return 'Legendary';
  }

  String get levelStars {
    return '⭐' * (level.clamp(1, 5));
  }

  // Type helpers
  String get typeDisplayName {
    switch (type.toLowerCase()) {
      case 'helmet':
        return 'Helmet';
      case 'shield':
        return 'Shield';
      case 'armor':
        return 'Armor';
      case 'weapon':
        return 'Weapon';
      case 'boots':
        return 'Boots';
      case 'gloves':
        return 'Gloves';
      default:
        return type
            .split(' ')
            .map((word) =>
                word[0].toUpperCase() + word.substring(1).toLowerCase())
            .join(' ');
    }
  }

  String get typeIcon {
    switch (type.toLowerCase()) {
      case 'helmet':
        return '⛑️';
      case 'shield':
        return '🛡️';
      case 'armor':
        return '🦺';
      case 'weapon':
        return '⚔️';
      case 'boots':
        return '👢';
      case 'gloves':
        return '🧤';
      default:
        return '🔧';
    }
  }

  IconData get typeIconData {
    switch (type.toLowerCase()) {
      case 'helmet':
        return Icons.sports_motorsports;
      case 'shield':
        return Icons.shield;
      case 'armor':
        return Icons.security;
      case 'weapon':
        return Icons.gavel;
      case 'boots':
        return Icons.directions_walk;
      case 'gloves':
        return Icons.back_hand;
      default:
        return Icons.build;
    }
  }

  // Biome helpers (same as ArtifactItem)
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
        return const Color(0xFF8B4513);
      case 'rocky':
        return const Color(0xFF808080);
      case 'desert':
        return const Color(0xFFF4A460);
      case 'forest':
        return const Color(0xFF228B22);
      case 'swamp':
        return const Color(0xFF556B2F);
      case 'volcanic':
        return const Color(0xFFFF4500);
      default:
        return Colors.grey;
    }
  }

  // Stats helpers (from properties)
  int get attack => getProperty<int>('attack') ?? 0;
  int get defense => getProperty<int>('defense') ?? 0;
  int get durability => getProperty<int>('durability') ?? 100;
  int get maxDurability => getProperty<int>('max_durability') ?? 100;
  double? get weight => getProperty<double>('weight');
  double? get value => getProperty<double>('value');

  // Durability helpers
  double get durabilityPercentage {
    if (maxDurability == 0) return 1.0;
    return (durability / maxDurability).clamp(0.0, 1.0);
  }

  String get durabilityDisplay {
    return '$durability / $maxDurability';
  }

  Color get durabilityColor {
    final percentage = durabilityPercentage;
    if (percentage > 0.7) return Colors.green;
    if (percentage > 0.4) return Colors.orange;
    return Colors.red;
  }

  bool get isBroken => durability <= 0;
  bool get needsRepair => durabilityPercentage < 0.3;

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

  // Status helpers
  bool get isDeleted => deletedAt != null;
  bool get isAvailable => isActive && !isDeleted && !isBroken;
  bool get canUse => isAvailable && durability > 0;

  // Copy with method
  GearItem copyWith({
    String? id,
    String? zoneId,
    String? name,
    String? type,
    int? level,
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
    return GearItem(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      name: name ?? this.name,
      type: type ?? this.type,
      level: level ?? this.level,
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
    return 'GearItem(id: $id, name: $name, type: $type, level: $level, biome: $biome)';
  }
}
