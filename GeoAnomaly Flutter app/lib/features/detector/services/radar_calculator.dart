// lib/features/detector/services/radar_calculator.dart
import 'dart:math' as math;
import '../models/detector_config.dart';

class RadarCalculator {
  // ✅ Calculate item position on radar
  static Map<String, double> calculateRadarPosition(
    double distance,
    double bearing,
    double maxRangeMeters,
  ) {
    // Normalize distance to radar display
    final normalizedDistance = (distance / maxRangeMeters).clamp(0.0, 1.0);
    final radiusFromCenter =
        normalizedDistance * (DetectorConfig.RADAR_DISPLAY_SIZE / 2 - 10);

    // Convert bearing to radar coordinates (North = up)
    final radians = (bearing - 90) * math.pi / 180;
    final x = radiusFromCenter * math.cos(radians);
    final y = radiusFromCenter * math.sin(radians);

    return {
      'x': x,
      'y': y,
      'normalizedDistance': normalizedDistance,
      'radiusFromCenter': radiusFromCenter,
    };
  }

  // ✅ Calculate bearing between two points
  static double calculateBearing(
      double lat1, double lon1, double lat2, double lon2) {
    final double dLon = _toRadians(lon2 - lon1);
    final double lat1Rad = _toRadians(lat1);
    final double lat2Rad = _toRadians(lat2);

    final double y = math.sin(dLon) * math.cos(lat2Rad);
    final double x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    final double bearingRad = math.atan2(y, x);
    final double bearingDeg = _toDegrees(bearingRad);

    return (bearingDeg + 360) % 360;
  }

  // ✅ Calculate distance using Haversine formula
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusMeters = 6371000;

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double lat1Rad = _toRadians(lat1);
    final double lat2Rad = _toRadians(lat2);

    final double a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.pow(math.sin(dLon / 2), 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  // ✅ Convert bearing to compass direction
  static String bearingToCompass(double bearing) {
    const List<String> directions = [
      'N',
      'NE',
      'E',
      'SE',
      'S',
      'SW',
      'W',
      'NW'
    ];
    final int index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  // ✅ Calculate signal strength
  static double calculateSignalStrength(
    double distanceMeters, {
    double maxRangeMeters = 500.0,
    double precisionFactor = 1.0,
    String? itemRarity,
  }) {
    if (distanceMeters <= 0) return 1.0;
    if (distanceMeters >= maxRangeMeters) return 0.0;

    // Base strength calculation
    double baseStrength = 1.0 - (distanceMeters / maxRangeMeters);
    baseStrength = math.pow(baseStrength, 1.0 / precisionFactor).toDouble();

    // Rarity bonus
    double rarityMultiplier = 1.0;
    switch (itemRarity?.toLowerCase()) {
      case 'legendary':
        rarityMultiplier = 1.5;
        break;
      case 'epic':
        rarityMultiplier = 1.3;
        break;
      case 'rare':
        rarityMultiplier = 1.2;
        break;
      case 'common':
      default:
        rarityMultiplier = 1.0;
        break;
    }

    return (baseStrength * rarityMultiplier).clamp(0.0, 1.0);
  }

  // ✅ Private helper methods
  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
  static double _toDegrees(double radians) => radians * 180.0 / math.pi;
}
