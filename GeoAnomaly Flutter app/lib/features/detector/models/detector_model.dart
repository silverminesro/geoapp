import 'package:flutter/material.dart';

class Detector {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final int range; // 1-5 stars
  final int precision; // 1-5 stars
  final int battery; // 1-5 stars (battery life)
  final int tierRequired;
  final bool isOwned;
  final DetectorRarity rarity;
  final String? specialAbility;

  const Detector({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.range,
    required this.precision,
    required this.battery,
    required this.tierRequired,
    required this.isOwned,
    required this.rarity,
    this.specialAbility,
  });

  // ✅ Missing getters that DetectorScreen needs
  double get maxRangeMeters =>
      range * 200.0; // Convert stars to meters (1 star = 200m)
  double get precisionFactor =>
      precision / 5.0; // Normalize precision (1-5 -> 0.2-1.0)

  String get rangeDisplay => '${(maxRangeMeters).toInt()}m';
  String get precisionDisplay => '$precision/5 ⭐';
  String get batteryDisplay => '$battery/5 ⭐';

  // Factory method from JSON
  factory Detector.fromJson(Map<String, dynamic> json) {
    return Detector(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: _getIconFromString(json['icon'] ?? 'search'),
      range: (json['range'] ?? 1).clamp(1, 5),
      precision: (json['precision'] ?? 1).clamp(1, 5),
      battery: (json['battery'] ?? 1).clamp(1, 5),
      tierRequired: json['tier_required'] ?? 0,
      isOwned: json['is_owned'] ?? false,
      rarity: DetectorRarity.values.firstWhere(
        (r) => r.name == (json['rarity'] ?? 'common'),
        orElse: () => DetectorRarity.common,
      ),
      specialAbility: json['special_ability'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': _iconToString(icon),
      'range': range,
      'precision': precision,
      'battery': battery,
      'tier_required': tierRequired,
      'is_owned': isOwned,
      'rarity': rarity.name,
      'special_ability': specialAbility,
    };
  }

  // Helper method for icons - FROM string
  static IconData _getIconFromString(String iconString) {
    switch (iconString.toLowerCase()) {
      case 'search':
        return Icons.search;
      case 'scanner':
        return Icons.scanner;
      case 'memory':
        return Icons.memory;
      case 'radar':
        return Icons.radar;
      case 'sensors':
        return Icons.sensors;
      case 'satellite':
        return Icons.satellite;
      case 'science':
        return Icons.science;
      case 'precision_manufacturing':
        return Icons.precision_manufacturing;
      default:
        return Icons.search;
    }
  }

  // Helper method for icons - TO string
  static String _iconToString(IconData icon) {
    if (icon == Icons.search) return 'search';
    if (icon == Icons.scanner) return 'scanner';
    if (icon == Icons.memory) return 'memory';
    if (icon == Icons.radar) return 'radar';
    if (icon == Icons.sensors) return 'sensors';
    if (icon == Icons.satellite) return 'satellite';
    if (icon == Icons.science) return 'science';
    if (icon == Icons.precision_manufacturing) return 'precision_manufacturing';
    return 'search';
  }

  // ✅ Default detectors that every player gets
  static final List<Detector> defaultDetectors = [
    Detector(
      id: 'basic_metal',
      name: 'Basic Metal Detector',
      description:
          'Simple handheld detector. Limited range but reliable for basic metal detection.',
      icon: Icons.search,
      range: 2,
      precision: 2,
      battery: 4,
      tierRequired: 0,
      isOwned: true, // ✅ Player starts with this
      rarity: DetectorRarity.common,
      specialAbility: 'Detects metal objects within 400m radius',
    ),
    Detector(
      id: 'ground_scanner',
      name: 'Ground Penetrating Radar',
      description:
          'Advanced ground scanning technology. Better depth and precision.',
      icon: Icons.scanner,
      range: 3,
      precision: 4,
      battery: 3,
      tierRequired: 1,
      isOwned: true, // ✅ For testing - normally false
      rarity: DetectorRarity.uncommon,
      specialAbility: 'Shows depth information and material type hints',
    ),
    Detector(
      id: 'quantum_detector',
      name: 'Quantum Field Detector',
      description:
          'Cutting-edge quantum technology. Extremely precise artifact detection.',
      icon: Icons.memory,
      range: 5,
      precision: 5,
      battery: 2,
      tierRequired: 3,
      isOwned: true,
      rarity: DetectorRarity.legendary,
      specialAbility: 'Pinpoint accuracy with artifact rarity prediction',
    ),
    Detector(
      id: 'electromagnetic',
      name: 'EM Field Scanner',
      description:
          'Detects electromagnetic anomalies. Great for electronic artifacts.',
      icon: Icons.sensors,
      range: 4,
      precision: 3,
      battery: 3,
      tierRequired: 2,
      isOwned: true,
      rarity: DetectorRarity.rare,
      specialAbility: 'Specializes in electronic and energy-based artifacts',
    ),
    Detector(
      id: 'precision_tracker',
      name: 'Precision Artifact Tracker',
      description:
          'Military-grade detection equipment with exceptional accuracy.',
      icon: Icons.precision_manufacturing,
      range: 3,
      precision: 5,
      battery: 4,
      tierRequired: 2,
      isOwned: true,
      rarity: DetectorRarity.epic,
      specialAbility: 'Ultra-precise targeting within 50cm accuracy',
    ),
  ];

  // Copy with method for updates
  Detector copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    int? range,
    int? precision,
    int? battery,
    int? tierRequired,
    bool? isOwned,
    DetectorRarity? rarity,
    String? specialAbility,
  }) {
    return Detector(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      range: range ?? this.range,
      precision: precision ?? this.precision,
      battery: battery ?? this.battery,
      tierRequired: tierRequired ?? this.tierRequired,
      isOwned: isOwned ?? this.isOwned,
      rarity: rarity ?? this.rarity,
      specialAbility: specialAbility ?? this.specialAbility,
    );
  }

  @override
  String toString() => 'Detector(id: $id, name: $name, owned: $isOwned)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Detector && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum DetectorRarity {
  common('Common', Color(0xFF9E9E9E)),
  uncommon('Uncommon', Color(0xFF4CAF50)),
  rare('Rare', Color(0xFF2196F3)),
  epic('Epic', Color(0xFF9C27B0)),
  legendary('Legendary', Color(0xFFFF9800));

  const DetectorRarity(this.displayName, this.color);
  final String displayName;
  final Color color;
}
