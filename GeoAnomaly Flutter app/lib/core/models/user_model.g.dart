// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      tier: (json['tier'] as num).toInt(),
      xp: (json['xp'] as num).toInt(),
      level: (json['level'] as num).toInt(),
      totalArtifacts: (json['total_artifacts'] as num).toInt(),
      totalGear: (json['total_gear'] as num).toInt(),
      zonesDiscovered: (json['zones_discovered'] as num).toInt(),
      isActive: json['is_active'] as bool,
      isBanned: json['is_banned'] as bool? ?? false,
      tierExpires: json['tier_expires'] as String?,
      lastLogin: json['last_login'] as String?,
      profileData: json['profile_data'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'tier': instance.tier,
      'xp': instance.xp,
      'level': instance.level,
      'total_artifacts': instance.totalArtifacts,
      'total_gear': instance.totalGear,
      'zones_discovered': instance.zonesDiscovered,
      'is_active': instance.isActive,
      'is_banned': instance.isBanned,
      'tier_expires': instance.tierExpires,
      'last_login': instance.lastLogin,
      'profile_data': instance.profileData,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
