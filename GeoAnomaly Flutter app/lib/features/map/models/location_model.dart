class LocationModel {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;

  LocationModel({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      accuracy: json['accuracy']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      if (accuracy != null) 'accuracy': accuracy,
    };
  }

  @override
  String toString() {
    return 'LocationModel(lat: $latitude, lng: $longitude, accuracy: $accuracy)';
  }
}
