// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zone_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Zone _$ZoneFromJson(Map<String, dynamic> json) => Zone(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
      radiusMeters: (json['radius_meters'] as num).toInt(),
      tierRequired: (json['tier_required'] as num).toInt(),
      zoneType: json['zone_type'] as String,
      biome: json['biome'] as String?,
      dangerLevel: json['danger_level'] as String?,
      isActive: json['is_active'] as bool,
      expiresAt: json['expires_at'] as String?,
      lastActivity: json['last_activity'] as String?,
      autoCleanup: json['auto_cleanup'] as bool? ?? true,
      properties: json['properties'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$ZoneToJson(Zone instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'location': instance.location,
      'radius_meters': instance.radiusMeters,
      'tier_required': instance.tierRequired,
      'zone_type': instance.zoneType,
      'biome': instance.biome,
      'danger_level': instance.dangerLevel,
      'is_active': instance.isActive,
      'expires_at': instance.expiresAt,
      'last_activity': instance.lastActivity,
      'auto_cleanup': instance.autoCleanup,
      'properties': instance.properties,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

Location _$LocationFromJson(Map<String, dynamic> json) => Location(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );

Map<String, dynamic> _$LocationToJson(Location instance) => <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };

ZoneWithDetails _$ZoneWithDetailsFromJson(Map<String, dynamic> json) =>
    ZoneWithDetails(
      zone: Zone.fromJson(json['zone'] as Map<String, dynamic>),
      distanceFromPlayer: (json['distanceFromPlayer'] as num?)?.toDouble(),
      artifactCount: (json['artifactCount'] as num?)?.toInt(),
      gearCount: (json['gearCount'] as num?)?.toInt(),
      canEnter: json['canEnter'] as bool,
      playerCount: (json['player_count'] as num?)?.toInt(),
      lastVisited: json['last_visited'] as String?,
      bearingFromPlayer: json['bearingFromPlayer'] as String?,
      compassDirection: json['compassDirection'] as String?,
    );

Map<String, dynamic> _$ZoneWithDetailsToJson(ZoneWithDetails instance) =>
    <String, dynamic>{
      'zone': instance.zone,
      'distanceFromPlayer': instance.distanceFromPlayer,
      'artifactCount': instance.artifactCount,
      'gearCount': instance.gearCount,
      'canEnter': instance.canEnter,
      'player_count': instance.playerCount,
      'last_visited': instance.lastVisited,
      'bearingFromPlayer': instance.bearingFromPlayer,
      'compassDirection': instance.compassDirection,
    };

ScanAreaResponse _$ScanAreaResponseFromJson(Map<String, dynamic> json) =>
    ScanAreaResponse(
      zonesCreated: (json['zones_created'] as num).toInt(),
      zones: (json['zones'] as List<dynamic>)
          .map((e) => ZoneWithDetails.fromJson(e as Map<String, dynamic>))
          .toList(),
      scanAreaCenter:
          Location.fromJson(json['scan_area_center'] as Map<String, dynamic>),
      nextScanAvailable: (json['next_scan_available'] as num).toInt(),
      maxZones: (json['max_zones'] as num).toInt(),
      currentZoneCount: (json['current_zone_count'] as num).toInt(),
      playerTier: (json['player_tier'] as num).toInt(),
    );

Map<String, dynamic> _$ScanAreaResponseToJson(ScanAreaResponse instance) =>
    <String, dynamic>{
      'zones_created': instance.zonesCreated,
      'zones': instance.zones,
      'scan_area_center': instance.scanAreaCenter,
      'next_scan_available': instance.nextScanAvailable,
      'max_zones': instance.maxZones,
      'current_zone_count': instance.currentZoneCount,
      'player_tier': instance.playerTier,
    };
