// ✅ User Model
class User {
  final String id;
  final String username;
  final String email;
  final int tier;
  final int level;
  final int xp;
  final int totalArtifacts;
  final int totalGear;
  final int zonesDiscovered;
  final bool isActive;
  final bool isBanned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.tier,
    required this.level,
    required this.xp,
    required this.totalArtifacts,
    required this.totalGear,
    required this.zonesDiscovered,
    required this.isActive,
    required this.isBanned,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      tier: (json['tier'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      totalArtifacts: (json['total_artifacts'] as num?)?.toInt() ?? 0,
      totalGear: (json['total_gear'] as num?)?.toInt() ?? 0,
      zonesDiscovered: (json['zones_discovered'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isBanned: json['is_banned'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'tier': tier,
      'level': level,
      'xp': xp,
      'total_artifacts': totalArtifacts,
      'total_gear': totalGear,
      'zones_discovered': zonesDiscovered,
      'is_active': isActive,
      'is_banned': isBanned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // ✅ Helper methods
  String get tierName {
    switch (tier) {
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

  String get tierEmoji {
    switch (tier) {
      case 0:
        return '🆓';
      case 1:
        return '⭐';
      case 2:
        return '⭐⭐';
      case 3:
        return '⭐⭐⭐';
      case 4:
        return '👑';
      default:
        return '❓';
    }
  }

  // ✅ Calculate level progress
  int get levelProgress {
    // Simple formula: level * 100 XP required
    final currentLevelXP = (level - 1) * 100;
    final nextLevelXP = level * 100;
    final progressInLevel = xp - currentLevelXP;
    final xpForNextLevel = nextLevelXP - currentLevelXP;

    if (xpForNextLevel <= 0) return 100;
    return ((progressInLevel / xpForNextLevel) * 100).clamp(0, 100).toInt();
  }

  // ✅ Get XP needed for next level
  int get xpToNextLevel {
    final nextLevelXP = level * 100;
    return (nextLevelXP - xp).clamp(0, double.infinity).toInt();
  }

  // ✅ Check if user can access tier
  bool canAccessTier(int requiredTier) {
    return tier >= requiredTier && isActive && !isBanned;
  }

  // ✅ Copy with method for updates
  User copyWith({
    String? id,
    String? username,
    String? email,
    int? tier,
    int? level,
    int? xp,
    int? totalArtifacts,
    int? totalGear,
    int? zonesDiscovered,
    bool? isActive,
    bool? isBanned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      tier: tier ?? this.tier,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      totalArtifacts: totalArtifacts ?? this.totalArtifacts,
      totalGear: totalGear ?? this.totalGear,
      zonesDiscovered: zonesDiscovered ?? this.zonesDiscovered,
      isActive: isActive ?? this.isActive,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, tier: $tier, level: $level)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ✅ Auth Response Model
class AuthResponse {
  final User user;
  final String token;
  final int expiresAt;

  const AuthResponse({
    required this.user,
    required this.token,
    required this.expiresAt,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user']),
      token: json['token'].toString(),
      expiresAt: (json['expires'] as num?)?.toInt() ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
              86400, // 24h default
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'token': token,
      'expires': expiresAt,
    };
  }

  // ✅ Check if token is expired
  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= expiresAt;
  }

  // ✅ Time until expiration
  Duration get timeUntilExpiry {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final secondsLeft = expiresAt - now;
    return Duration(seconds: secondsLeft.clamp(0, double.infinity).toInt());
  }

  @override
  String toString() {
    return 'AuthResponse(user: ${user.username}, token: ${token.substring(0, 20)}...)';
  }
}

// ✅ Login Request Model
class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({
    required this.username,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) {
    return LoginRequest(
      username: json['username'].toString(),
      password: json['password'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}

// ✅ Register Request Model
class RegisterRequest {
  final String username;
  final String email;
  final String password;

  const RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) {
    return RegisterRequest(
      username: json['username'].toString(),
      email: json['email'].toString(),
      password: json['password'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'password': password,
    };
  }

  // ✅ Validation
  bool get isValid {
    return username.isNotEmpty &&
        email.isNotEmpty &&
        password.isNotEmpty &&
        email.contains('@') &&
        password.length >= 8;
  }

  String? get validationError {
    if (username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (email.isEmpty) return 'Email is required';
    if (!email.contains('@')) return 'Invalid email format';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters';
    return null;
  }
}
