import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'user_model.g.dart';

@JsonSerializable()
class User extends Equatable {
  final String id;
  final String username;
  final String email;
  final int tier;
  final int xp;
  final int level;

  @JsonKey(name: 'total_artifacts')
  final int totalArtifacts;

  @JsonKey(name: 'total_gear')
  final int totalGear;

  @JsonKey(name: 'zones_discovered')
  final int zonesDiscovered;

  @JsonKey(name: 'is_active')
  final bool isActive;

  // ✅ NEW: Additional fields that might come from backend
  @JsonKey(name: 'is_banned', defaultValue: false)
  final bool isBanned;

  @JsonKey(name: 'tier_expires')
  final String? tierExpires;

  @JsonKey(name: 'last_login')
  final String? lastLogin;

  @JsonKey(name: 'profile_data', defaultValue: <String, dynamic>{})
  final Map<String, dynamic> profileData;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.tier,
    required this.xp,
    required this.level,
    required this.totalArtifacts,
    required this.totalGear,
    required this.zonesDiscovered,
    required this.isActive,
    this.isBanned = false,
    this.tierExpires,
    this.lastLogin,
    this.profileData = const <String, dynamic>{},
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        tier,
        xp,
        level,
        totalArtifacts,
        totalGear,
        zonesDiscovered,
        isActive,
        isBanned,
        tierExpires,
        lastLogin,
        profileData,
        createdAt,
        updatedAt,
      ];

  // ✅ NEW: Helper methods
  bool get isPremium => tier > 0;
  bool get isBasicTier => tier == 0;
  bool get canAccessTier => !isBanned && isActive;

  String get displayName => username;
  String get tierName {
    switch (tier) {
      case 0:
        return 'Free';
      case 1:
        return 'Basic';
      case 2:
        return 'Premium';
      case 3:
        return 'Pro';
      case 4:
        return 'Elite';
      default:
        return 'Unknown';
    }
  }

  // ✅ NEW: Copy with method for state updates
  User copyWith({
    String? id,
    String? username,
    String? email,
    int? tier,
    int? xp,
    int? level,
    int? totalArtifacts,
    int? totalGear,
    int? zonesDiscovered,
    bool? isActive,
    bool? isBanned,
    String? tierExpires,
    String? lastLogin,
    Map<String, dynamic>? profileData,
    String? createdAt,
    String? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      tier: tier ?? this.tier,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      totalArtifacts: totalArtifacts ?? this.totalArtifacts,
      totalGear: totalGear ?? this.totalGear,
      zonesDiscovered: zonesDiscovered ?? this.zonesDiscovered,
      isActive: isActive ?? this.isActive,
      isBanned: isBanned ?? this.isBanned,
      tierExpires: tierExpires ?? this.tierExpires,
      lastLogin: lastLogin ?? this.lastLogin,
      profileData: profileData ?? this.profileData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'User(id: $id, username: $username, tier: $tier, level: $level)';
}
