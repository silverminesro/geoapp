import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import '../../map/models/location_model.dart';

part 'inventory_item_model.g.dart';

@JsonSerializable()
class InventoryItem extends Equatable {
  final String id;

  @JsonKey(name: 'item_id')
  final String itemId;

  @JsonKey(name: 'item_type')
  final String itemType;

  final String name;
  final String rarity;
  final int quantity;

  @JsonKey(name: 'acquired_at')
  final DateTime acquiredAt;

  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @JsonKey(name: 'user_id')
  final String? userId;

  final Map<String, dynamic> properties;

  @JsonKey(name: 'discovery_location')
  final LocationModel? discoveryLocation;

  @JsonKey(name: 'location_timestamp')
  final DateTime? locationTimestamp;

  @JsonKey(name: 'is_favorite', defaultValue: false)
  final bool isFavorite;

  const InventoryItem({
    required this.id,
    required this.itemId,
    required this.itemType,
    required this.name,
    required this.rarity,
    required this.quantity,
    required this.acquiredAt,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.properties = const <String, dynamic>{},
    this.discoveryLocation,
    this.locationTimestamp,
    this.isFavorite = false,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) =>
      _$InventoryItemFromJson(json);
  Map<String, dynamic> toJson() => _$InventoryItemToJson(this);

  @override
  List<Object?> get props => [
        id,
        itemId,
        itemType,
        name,
        rarity,
        quantity,
        acquiredAt,
        createdAt,
        updatedAt,
        userId,
        properties,
        discoveryLocation,
        locationTimestamp,
        isFavorite,
      ];

  // Helper getters
  bool get isArtifact => itemType.toLowerCase() == 'artifact';
  bool get isGear => itemType.toLowerCase() == 'gear';

  String get displayName => name;
  String get displayRarity {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 'Common';
      case 'rare':
        return 'Rare';
      case 'epic':
        return 'Epic';
      case 'legendary':
        return 'Legendary';
      default:
        if (rarity.startsWith('level_')) {
          final level = rarity.substring(6);
          return 'Level $level';
        }
        return rarity.toUpperCase();
    }
  }

  // ✅ PRIDAJ TIETO CHÝBAJÚCE GETTERY:
  String get timeSinceAcquired {
    final now = DateTime.now();
    final difference = now.difference(acquiredAt);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return '1 day ago';
      } else if (difference.inDays < 30) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return months == 1 ? '1 month ago' : '$months months ago';
      } else {
        final years = (difference.inDays / 365).floor();
        return years == 1 ? '1 year ago' : '$years years ago';
      }
    } else if (difference.inHours > 0) {
      return difference.inHours == 1
          ? '1 hour ago'
          : '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return difference.inMinutes == 1
          ? '1 minute ago'
          : '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  String get acquiredDateFormatted {
    return '${acquiredAt.day}/${acquiredAt.month}/${acquiredAt.year}';
  }

  String get acquiredTimeFormatted {
    return '${acquiredAt.hour.toString().padLeft(2, '0')}:${acquiredAt.minute.toString().padLeft(2, '0')}';
  }

  String get acquiredDateTimeFormatted {
    return '$acquiredDateFormatted at $acquiredTimeFormatted';
  }

  String get biomeEmoji {
    final biome = getProperty<String>('biome')?.toLowerCase();
    switch (biome) {
      case 'forest':
        return '🌲';
      case 'swamp':
        return '🐸';
      case 'desert':
        return '🏜️';
      case 'mountain':
        return '⛰️';
      case 'wasteland':
        return '☠️';
      case 'volcanic':
        return '🌋';
      default:
        return '🌍';
    }
  }

  String get biomeDisplayName {
    final biome = getProperty<String>('biome');
    if (biome == null) return 'Unknown';
    return biome[0].toUpperCase() + biome.substring(1).toLowerCase();
  }

  bool get hasDiscoveryLocation => discoveryLocation != null;
  // ✅ KONIEC PRIDANÝCH GETTEROV

  // Property helpers
  T? getProperty<T>(String key) {
    return properties[key] as T?;
  }

  bool hasProperty(String key) {
    return properties.containsKey(key);
  }

  String get typeDisplayName {
    switch (itemType.toLowerCase()) {
      case 'artifact':
        return 'Artifact';
      case 'gear':
        return 'Equipment';
      default:
        return itemType;
    }
  }

  // Copy with method
  InventoryItem copyWith({
    String? id,
    String? itemId,
    String? itemType,
    String? name,
    String? rarity,
    int? quantity,
    DateTime? acquiredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    Map<String, dynamic>? properties,
    LocationModel? discoveryLocation,
    DateTime? locationTimestamp,
    bool? isFavorite,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      itemType: itemType ?? this.itemType,
      name: name ?? this.name,
      rarity: rarity ?? this.rarity,
      quantity: quantity ?? this.quantity,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      properties: properties ?? this.properties,
      discoveryLocation: discoveryLocation ?? this.discoveryLocation,
      locationTimestamp: locationTimestamp ?? this.locationTimestamp,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  String toString() =>
      'InventoryItem(id: $id, name: $name, type: $itemType, rarity: $rarity)';
}
