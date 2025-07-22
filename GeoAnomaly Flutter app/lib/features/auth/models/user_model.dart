class User {
  final String id;
  final String username;
  final String email;
  final int tier;
  final int level;
  final int xp;
  final int totalArtifacts;
  final int totalGear;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.tier,
    required this.level,
    required this.xp,
    required this.totalArtifacts,
    required this.totalGear,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      tier: json['tier'] ?? 0,
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      totalArtifacts: json['total_artifacts'] ?? 0,
      totalGear: json['total_gear'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
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
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
