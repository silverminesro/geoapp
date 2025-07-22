import '../../../core/models/zone_model.dart';
import 'location_model.dart';

class ScanResultModel {
  final int zonesCreated;
  final List<ZoneWithDetails> zones; // ✅ FIX: ZoneWithDetails namiesto Zone
  final LocationModel scanAreaCenter;
  final int nextScanAvailable;
  final int maxZones;
  final int currentZoneCount;
  final int playerTier;

  ScanResultModel({
    required this.zonesCreated,
    required this.zones,
    required this.scanAreaCenter,
    required this.nextScanAvailable,
    required this.maxZones,
    required this.currentZoneCount,
    required this.playerTier,
  });

  factory ScanResultModel.fromJson(Map<String, dynamic> json) {
    return ScanResultModel(
      zonesCreated: (json['zones_created'] as num?)?.toInt() ?? 0,
      zones: (json['zones'] as List? ?? [])
          .map((zoneData) =>
              ZoneWithDetails.fromJson(zoneData)) // ✅ FIX: ZoneWithDetails
          .toList(),
      scanAreaCenter: LocationModel.fromJson(json['scan_area_center'] ?? {}),
      nextScanAvailable: (json['next_scan_available'] as num?)?.toInt() ?? 0,
      maxZones: (json['max_zones'] as num?)?.toInt() ?? 0,
      currentZoneCount: (json['current_zone_count'] as num?)?.toInt() ?? 0,
      playerTier: (json['player_tier'] as num?)?.toInt() ?? 0,
    );
  }

  bool get canScanAgain {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= nextScanAvailable;
  }

  Duration get cooldownRemaining {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = nextScanAvailable - now;
    return Duration(seconds: remaining > 0 ? remaining : 0);
  }

  // ✅ Helper method to get just Zone objects
  List<Zone> get zoneObjects {
    return zones.map((zoneWithDetails) => zoneWithDetails.zone).toList();
  }
}

// ✅ NEW: ZoneWithDetails class for backend response
class ZoneWithDetails {
  final Zone zone;
  final double distanceMeters;
  final bool canEnter;
  final int activeArtifacts;
  final int activeGear;
  final int activePlayers;
  final int expiresAt;
  final String timeToExpiry;
  final String biome;
  final String dangerLevel;

  ZoneWithDetails({
    required this.zone,
    required this.distanceMeters,
    required this.canEnter,
    required this.activeArtifacts,
    required this.activeGear,
    required this.activePlayers,
    required this.expiresAt,
    required this.timeToExpiry,
    required this.biome,
    required this.dangerLevel,
  });

  factory ZoneWithDetails.fromJson(Map<String, dynamic> json) {
    return ZoneWithDetails(
      zone: Zone.fromJson(json['zone'] ?? {}), // ✅ Parse nested zone object
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      canEnter: json['can_enter'] as bool? ?? false,
      activeArtifacts: (json['active_artifacts'] as num?)?.toInt() ?? 0,
      activeGear: (json['active_gear'] as num?)?.toInt() ?? 0,
      activePlayers: (json['active_players'] as num?)?.toInt() ?? 0,
      expiresAt:
          (json['expires_at'] as num?)?.toInt() ?? 0, // ✅ int namiesto String
      timeToExpiry: json['time_to_expiry']?.toString() ?? '',
      biome: json['biome']?.toString() ?? '',
      dangerLevel: json['danger_level']?.toString() ?? '',
    );
  }

  // ✅ Helper methods
  DateTime get expiryDateTime {
    return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
  }

  bool get isExpired {
    return DateTime.now().isAfter(expiryDateTime);
  }

  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()}m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  String get statusText {
    if (isExpired) return 'Expired';
    if (activeArtifacts == 0 && activeGear == 0) return 'Empty';
    if (activePlayers > 0) return 'Active ($activePlayers players)';
    return 'Available';
  }
}
