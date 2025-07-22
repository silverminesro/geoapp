// lib/core/models/zone_model.dart
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'dart:math';

part 'zone_model.g.dart';

@JsonSerializable()
class Zone extends Equatable {
  final String id;
  final String name;
  final String? description;
  final Location location;

  @JsonKey(name: 'radius_meters')
  final int radiusMeters;

  @JsonKey(name: 'tier_required')
  final int tierRequired;

  @JsonKey(name: 'zone_type')
  final String zoneType;

  final String? biome;

  @JsonKey(name: 'danger_level')
  final String? dangerLevel;

  @JsonKey(name: 'is_active')
  final bool isActive;

  // ✅ TTL and cleanup fields from backend
  @JsonKey(name: 'expires_at')
  final String? expiresAt;

  @JsonKey(name: 'last_activity')
  final String? lastActivity;

  @JsonKey(name: 'auto_cleanup', defaultValue: true)
  final bool autoCleanup;

  @JsonKey(name: 'properties', defaultValue: <String, dynamic>{})
  final Map<String, dynamic> properties;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const Zone({
    required this.id,
    required this.name,
    this.description,
    required this.location,
    required this.radiusMeters,
    required this.tierRequired,
    required this.zoneType,
    this.biome,
    this.dangerLevel,
    required this.isActive,
    this.expiresAt,
    this.lastActivity,
    this.autoCleanup = true,
    this.properties = const <String, dynamic>{},
    this.createdAt,
    this.updatedAt,
  });

  factory Zone.fromJson(Map<String, dynamic> json) => _$ZoneFromJson(json);
  Map<String, dynamic> toJson() => _$ZoneToJson(this);

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        location,
        radiusMeters,
        tierRequired,
        zoneType,
        biome,
        dangerLevel,
        isActive,
        expiresAt,
        lastActivity,
        autoCleanup,
        properties,
        createdAt,
        updatedAt,
      ];

  // ✅ Zone type helpers
  bool get isDynamic => zoneType == 'dynamic';
  bool get isStatic => zoneType == 'static';
  bool get isEvent => zoneType == 'event';
  bool get isPermanent => expiresAt == null;

  String get displayBiome => biome ?? 'Unknown';
  String get displayDangerLevel => dangerLevel ?? 'Unknown';

  // ✅ MERGED: Tier helper from features version
  String get tierName {
    switch (tierRequired) {
      case 0:
        return 'Free';
      case 1:
        return 'Basic';
      case 2:
        return 'Standard';
      case 3:
        return 'Premium';
      case 4:
        return 'Elite';
      default:
        return 'Unknown';
    }
  }

  // ✅ MERGED: Emoji helpers from features version
  String get dangerLevelEmoji {
    switch (dangerLevel?.toLowerCase()) {
      case 'low':
        return '🟢';
      case 'medium':
        return '🟡';
      case 'high':
        return '🟠';
      case 'extreme':
        return '🔴';
      default:
        return '⚪';
    }
  }

  String get biomeEmoji {
    switch (biome?.toLowerCase()) {
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

  // ✅ Zone status display helpers
  String get zoneTypeDisplayName {
    switch (zoneType) {
      case 'static':
        return 'Static Zone';
      case 'dynamic':
        return 'Dynamic Zone';
      case 'event':
        return 'Event Zone';
      default:
        return 'Unknown Zone';
    }
  }

  String get dangerLevelDisplayName {
    switch (dangerLevel?.toLowerCase()) {
      case 'low':
        return 'Low Risk';
      case 'medium':
        return 'Medium Risk';
      case 'high':
        return 'High Risk';
      case 'extreme':
        return 'Extreme Risk';
      default:
        return 'Unknown Risk';
    }
  }

  // ✅ Distance calculation helper
  double distanceFromPoint(double lat, double lng) {
    return _calculateDistance(lat, lng, location.latitude, location.longitude);
  }

  bool isWithinRange(double lat, double lng) {
    final distance = distanceFromPoint(lat, lng);
    return distance <= radiusMeters;
  }

  // ✅ Enhanced expiry helpers
  DateTime? get expiryDateTime {
    if (expiresAt == null) return null;
    try {
      return DateTime.parse(expiresAt!);
    } catch (e) {
      return null;
    }
  }

  bool get isExpired {
    final expiry = expiryDateTime;
    return expiry != null && DateTime.now().isAfter(expiry);
  }

  Duration? get timeUntilExpiry {
    final expiry = expiryDateTime;
    if (expiry == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiry)) return Duration.zero;
    return expiry.difference(now);
  }

  String get expiryDisplayText {
    if (isPermanent) return 'Permanent';
    if (isExpired) return 'Expired';

    final timeLeft = timeUntilExpiry;
    if (timeLeft == null) return 'Unknown';

    if (timeLeft.inDays > 0) {
      return '${timeLeft.inDays}d ${timeLeft.inHours % 24}h left';
    } else if (timeLeft.inHours > 0) {
      return '${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m left';
    } else if (timeLeft.inMinutes > 0) {
      return '${timeLeft.inMinutes}m ${timeLeft.inSeconds % 60}s left';
    } else {
      return '${timeLeft.inSeconds}s left';
    }
  }

  // ✅ Copy with method
  Zone copyWith({
    String? id,
    String? name,
    String? description,
    Location? location,
    int? radiusMeters,
    int? tierRequired,
    String? zoneType,
    String? biome,
    String? dangerLevel,
    bool? isActive,
    String? expiresAt,
    String? lastActivity,
    bool? autoCleanup,
    Map<String, dynamic>? properties,
    String? createdAt,
    String? updatedAt,
  }) {
    return Zone(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      tierRequired: tierRequired ?? this.tierRequired,
      zoneType: zoneType ?? this.zoneType,
      biome: biome ?? this.biome,
      dangerLevel: dangerLevel ?? this.dangerLevel,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      lastActivity: lastActivity ?? this.lastActivity,
      autoCleanup: autoCleanup ?? this.autoCleanup,
      properties: properties ?? this.properties,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Zone(id: $id, name: $name, type: $zoneType, tier: $tierRequired)';
}

@JsonSerializable()
class Location extends Equatable {
  final double latitude;
  final double longitude;

  const Location({
    required this.latitude,
    required this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);
  Map<String, dynamic> toJson() => _$LocationToJson(this);

  @override
  List<Object?> get props => [latitude, longitude];

  // ✅ Location helpers
  String get coordinatesString =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  String get coordinatesDisplayShort =>
      '${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}';

  double distanceTo(Location other) {
    return _calculateDistance(
        latitude, longitude, other.latitude, other.longitude);
  }

  // ✅ Bearing calculation to another location
  double bearingTo(Location other) {
    final dLon = _toRadians(other.longitude - longitude);
    final lat1Rad = _toRadians(latitude);
    final lat2Rad = _toRadians(other.latitude);

    final y = sin(dLon) * cos(lat2Rad);
    final x =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearingRad = atan2(y, x);
    final bearingDeg = _toDegrees(bearingRad);

    // Normalize to 0-360 degrees
    return (bearingDeg + 360) % 360;
  }

  // ✅ Compass direction helper
  String compassDirectionTo(Location other) {
    final bearing = bearingTo(other);
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  Location copyWith({
    double? latitude,
    double? longitude,
  }) {
    return Location(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  String toString() => 'Location(lat: $latitude, lng: $longitude)';
}

// ✅ Zone with additional data for UI
@JsonSerializable()
class ZoneWithDetails extends Equatable {
  final Zone zone;
  final double? distanceFromPlayer;
  final int? artifactCount;
  final int? gearCount;
  final bool canEnter;

  @JsonKey(name: 'player_count')
  final int? playerCount;

  @JsonKey(name: 'last_visited')
  final String? lastVisited;

  // ✅ ENHANCED: Additional UI helper fields
  final String? bearingFromPlayer;
  final String? compassDirection;

  const ZoneWithDetails({
    required this.zone,
    this.distanceFromPlayer,
    this.artifactCount,
    this.gearCount,
    required this.canEnter,
    this.playerCount,
    this.lastVisited,
    this.bearingFromPlayer,
    this.compassDirection,
  });

  factory ZoneWithDetails.fromJson(Map<String, dynamic> json) =>
      _$ZoneWithDetailsFromJson(json);
  Map<String, dynamic> toJson() => _$ZoneWithDetailsToJson(this);

  @override
  List<Object?> get props => [
        zone,
        distanceFromPlayer,
        artifactCount,
        gearCount,
        canEnter,
        playerCount,
        lastVisited,
        bearingFromPlayer,
        compassDirection,
      ];

  // ✅ UI helper methods
  String get distanceDisplay {
    if (distanceFromPlayer == null) return 'Unknown distance';

    final distance = distanceFromPlayer!;
    if (distance < 1.0) {
      return '${(distance * 100).toInt()}cm away';
    } else if (distance < 1000) {
      return '${distance.toInt()}m away';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km away';
    }
  }

  String get itemCountDisplay {
    final artifacts = artifactCount ?? 0;
    final gear = gearCount ?? 0;
    final total = artifacts + gear;

    if (total == 0) return 'No items';
    return '$total items ($artifacts artifacts, $gear gear)';
  }

  String get playerCountDisplay {
    final count = playerCount ?? 0;
    if (count == 0) return 'Empty';
    if (count == 1) return '1 player';
    return '$count players';
  }

  String get directionDisplay {
    return compassDirection ?? bearingFromPlayer ?? 'Unknown';
  }

  bool get isVeryClose =>
      distanceFromPlayer != null && distanceFromPlayer! <= 5.0;
  bool get isClose => distanceFromPlayer != null && distanceFromPlayer! <= 50.0;
  bool get isNearby =>
      distanceFromPlayer != null && distanceFromPlayer! <= 500.0;

  // ✅ Status helpers
  String get statusDisplay {
    if (zone.isExpired) return 'Expired';
    if (!zone.isActive) return 'Inactive';
    if (!canEnter) return 'Restricted';
    if (isVeryClose) return 'Very Close';
    if (isClose) return 'Close';
    if (isNearby) return 'Nearby';
    return 'Distant';
  }

  Color get statusColor {
    if (zone.isExpired || !zone.isActive) return const Color(0xFF666666);
    if (!canEnter) return const Color(0xFFFF5722);
    if (isVeryClose) return const Color(0xFF4CAF50);
    if (isClose) return const Color(0xFF8BC34A);
    if (isNearby) return const Color(0xFFFFC107);
    return const Color(0xFF9E9E9E);
  }

  @override
  String toString() =>
      'ZoneWithDetails(zone: ${zone.name}, distance: $distanceFromPlayer, canEnter: $canEnter)';
}

// ✅ Scan area response model
@JsonSerializable()
class ScanAreaResponse extends Equatable {
  @JsonKey(name: 'zones_created')
  final int zonesCreated;

  final List<ZoneWithDetails> zones;

  @JsonKey(name: 'scan_area_center')
  final Location scanAreaCenter;

  @JsonKey(name: 'next_scan_available')
  final int nextScanAvailable;

  @JsonKey(name: 'max_zones')
  final int maxZones;

  @JsonKey(name: 'current_zone_count')
  final int currentZoneCount;

  @JsonKey(name: 'player_tier')
  final int playerTier;

  const ScanAreaResponse({
    required this.zonesCreated,
    required this.zones,
    required this.scanAreaCenter,
    required this.nextScanAvailable,
    required this.maxZones,
    required this.currentZoneCount,
    required this.playerTier,
  });

  factory ScanAreaResponse.fromJson(Map<String, dynamic> json) =>
      _$ScanAreaResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ScanAreaResponseToJson(this);

  @override
  List<Object?> get props => [
        zonesCreated,
        zones,
        scanAreaCenter,
        nextScanAvailable,
        maxZones,
        currentZoneCount,
        playerTier,
      ];

  // ✅ Helper getters
  bool get canScanAgain {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= nextScanAvailable;
  }

  Duration get cooldownRemaining {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = nextScanAvailable - now;
    return Duration(seconds: remaining > 0 ? remaining : 0);
  }

  String get cooldownDisplay {
    if (canScanAgain) return 'Ready to scan';

    final remaining = cooldownRemaining;
    if (remaining.inMinutes > 0) {
      return 'Cooldown: ${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
    } else {
      return 'Cooldown: ${remaining.inSeconds}s';
    }
  }

  @override
  String toString() =>
      'ScanAreaResponse(created: $zonesCreated, found: ${zones.length})';
}

// ✅ Utility functions
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371000; // Earth's radius in meters

  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}

double _toRadians(double degrees) {
  return degrees * pi / 180;
}

double _toDegrees(double radians) {
  return radians * 180 / pi;
}
