// lib/features/detector/models/artifact_model.dart
import 'package:equatable/equatable.dart';
import 'detector_config.dart';

class DetectableItem extends Equatable {
  final String id;
  final String name;
  final String type;
  final String rarity;
  final String material;
  final double latitude;
  final double longitude;
  final int value;
  final String description;
  final bool canBeDetected;
  final double detectionDifficulty;

  // ✅ NEW: Source type from backend (artifact vs gear)
  final String? sourceType;

  // ✅ NEW: Level field for gear items
  final int? level;

  // Runtime calculated properties
  final double? distanceFromPlayer;
  final double? bearingFromPlayer;
  final String? compassDirection;

  const DetectableItem({
    required this.id,
    required this.name,
    required this.type,
    required this.rarity,
    required this.material,
    required this.latitude,
    required this.longitude,
    required this.value,
    required this.description,
    this.canBeDetected = true,
    this.detectionDifficulty = 1.0,
    this.sourceType, // ✅ NEW
    this.level, // ✅ NEW
    this.distanceFromPlayer,
    this.bearingFromPlayer,
    this.compassDirection,
  });

  // ✅ COMPLETELY REWRITTEN: Enhanced JSON parsing with smart type detection
  factory DetectableItem.fromJson(Map<String, dynamic> json) {
    // ✅ Better handling of nested location data
    double lat = 0.0;
    double lng = 0.0;

    if (json['location'] != null) {
      if (json['location'] is Map) {
        lat = (json['location']['latitude'] as num?)?.toDouble() ?? 0.0;
        lng = (json['location']['longitude'] as num?)?.toDouble() ?? 0.0;
      }
    } else {
      // Fallback: check for direct lat/lng fields
      lat = (json['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (json['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    // ✅ NEW: Extract source type from JSON (set by detection_service)
    final sourceType = json['source_type']?.toString();

    // ✅ NEW: Extract level for gear items
    final level = (json['level'] as num?)?.toInt();

    // ✅ NEW: Smart type detection based on data
    String itemType = json['type']?.toString() ?? 'unknown';

    // Override type based on source if available
    if (sourceType != null) {
      print('🔍 Using source type: $sourceType for ${json['name']}');
      // Keep original type but store source for collection
    }

    // If level exists, hint that it might be gear
    if (level != null && level > 0) {
      print('🔍 Item ${json['name']} has level $level, likely gear');
    }

    return DetectableItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Item',
      type: itemType,
      rarity: json['rarity']?.toString() ?? 'common',
      material: json['material']?.toString() ?? 'metal',
      latitude: lat,
      longitude: lng,
      value: (json['value'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString() ?? '',
      canBeDetected: json['can_be_detected'] ?? true,
      detectionDifficulty:
          (json['detection_difficulty'] as num?)?.toDouble() ?? 1.0,
      sourceType: sourceType, // ✅ NEW
      level: level, // ✅ NEW
      distanceFromPlayer: (json['distance_from_player'] as num?)?.toDouble(),
      bearingFromPlayer: (json['bearing_from_player'] as num?)?.toDouble(),
      compassDirection: json['compass_direction']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'rarity': rarity,
      'material': material,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'value': value,
      'description': description,
      'can_be_detected': canBeDetected,
      'detection_difficulty': detectionDifficulty,
      'source_type': sourceType, // ✅ NEW
      'level': level, // ✅ NEW
      'distance_from_player': distanceFromPlayer,
      'bearing_from_player': bearingFromPlayer,
      'compass_direction': compassDirection,
    };
  }

  // Helper getters that DetectorScreen needs
  String get rarityDisplayName {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 'Common';
      case 'uncommon':
        return 'Uncommon';
      case 'rare':
        return 'Rare';
      case 'epic':
        return 'Epic';
      case 'legendary':
        return 'Legendary';
      default:
        return 'Unknown';
    }
  }

  String get materialDisplayName {
    switch (material.toLowerCase()) {
      case 'metal':
        return 'Metal';
      case 'stone':
        return 'Stone';
      case 'crystal':
        return 'Crystal';
      case 'organic':
        return 'Organic';
      case 'magical':
        return 'Magical';
      case 'electronic':
        return 'Electronic';
      case 'ceramic':
        return 'Ceramic';
      case 'bone':
        return 'Bone';
      case 'wood':
        return 'Wood';
      default:
        return material.toUpperCase();
    }
  }

  String get distanceDisplay {
    if (distanceFromPlayer == null) return 'Unknown';

    final distance = distanceFromPlayer!;
    if (distance < 1.0) {
      return '${(distance * 100).toInt()}cm';
    } else if (distance < 1000.0) {
      return '${distance.toInt()}m';
    } else {
      return '${(distance / 1000.0).toStringAsFixed(1)}km';
    }
  }

  // ✅ FIX: Add compass direction fallback
  String get compassDirectionDisplay {
    return compassDirection ?? bearingToCompass(bearingFromPlayer ?? 0.0);
  }

  // ✅ NEW: Convert bearing to compass direction
  String bearingToCompass(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  // ✅ Uses DetectorConfig for proximity checks
  bool get isVeryClose =>
      distanceFromPlayer != null &&
      distanceFromPlayer! <= DetectorConfig.collectionRadius;

  bool get isClose =>
      distanceFromPlayer != null &&
      distanceFromPlayer! <= DetectorConfig.CLOSE_PROXIMITY_RADIUS;

  bool get hasValidLocation => latitude != 0.0 || longitude != 0.0;

  // ✅ NEW: Enhanced debug info including type detection
  String get debugProximityInfo {
    if (distanceFromPlayer == null) return 'No distance data';

    final distance = distanceFromPlayer!;
    final collectionRadius = DetectorConfig.collectionRadius;
    final closeRadius = DetectorConfig.CLOSE_PROXIMITY_RADIUS;

    return 'Distance: ${distanceDisplay} | '
        'Collection: ${distance <= collectionRadius ? '✅' : '❌'} (≤${collectionRadius.toInt()}m) | '
        'Close: ${distance <= closeRadius ? '✅' : '❌'} (≤${closeRadius.toInt()}m) | '
        'Source: ${sourceType ?? 'unknown'} | '
        'Level: ${level ?? 'none'}';
  }

  // ✅ NEW: Type detection helpers
  bool get isGearItem => sourceType == 'gear' || (level != null && level! > 0);
  bool get isArtifactItem =>
      sourceType == 'artifact' ||
      (sourceType == null && (level == null || level == 0));

  String get detectedItemType {
    if (sourceType != null) return sourceType!;
    if (level != null && level! > 0) return 'gear';
    return 'artifact';
  }

  DetectableItem copyWith({
    String? id,
    String? name,
    String? type,
    String? rarity,
    String? material,
    double? latitude,
    double? longitude,
    int? value,
    String? description,
    bool? canBeDetected,
    double? detectionDifficulty,
    String? sourceType, // ✅ NEW
    int? level, // ✅ NEW
    double? distanceFromPlayer,
    double? bearingFromPlayer,
    String? compassDirection,
  }) {
    return DetectableItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rarity: rarity ?? this.rarity,
      material: material ?? this.material,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      value: value ?? this.value,
      description: description ?? this.description,
      canBeDetected: canBeDetected ?? this.canBeDetected,
      detectionDifficulty: detectionDifficulty ?? this.detectionDifficulty,
      sourceType: sourceType ?? this.sourceType, // ✅ NEW
      level: level ?? this.level, // ✅ NEW
      distanceFromPlayer: distanceFromPlayer ?? this.distanceFromPlayer,
      bearingFromPlayer: bearingFromPlayer ?? this.bearingFromPlayer,
      compassDirection: compassDirection ?? this.compassDirection,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        rarity,
        material,
        latitude,
        longitude,
        value,
        description,
        canBeDetected,
        detectionDifficulty,
        sourceType, // ✅ NEW
        level, // ✅ NEW
        distanceFromPlayer,
        bearingFromPlayer,
        compassDirection,
      ];

  @override
  String toString() =>
      'DetectableItem(id: $id, name: $name, type: $type, source: ${sourceType ?? 'unknown'}, level: ${level ?? 'none'}, rarity: $rarity, distance: ${distanceDisplay})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DetectableItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
