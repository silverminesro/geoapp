// lib/features/detector/models/detector_config.dart
class DetectorConfig {
  // ✅ Proximity settings - 20m pre testovanie!
  static const double COLLECTION_RADIUS_DEBUG = 400.0; // ✅ Z 20m na 30m
  static const double COLLECTION_RADIUS_PROD = 2.0; // Zostáva rovnaké
  static const double CLOSE_PROXIMITY_RADIUS = 500.0; // ✅ Z 10m na 50m

  // ✅ Update intervals - zrýchlené pre lepší UX
  static const Duration DETECTION_UPDATE_INTERVAL = Duration(seconds: 2);
  static const Duration LOCATION_UPDATE_INTERVAL = Duration(seconds: 1);
  static const Duration SCAN_ANIMATION_DURATION = Duration(seconds: 2);
  static const Duration SIGNAL_ANIMATION_DURATION =
      Duration(milliseconds: 1000);

  // ✅ Radar settings
  static const int MAX_RADAR_ITEMS = 10;
  static const double RADAR_DISPLAY_SIZE = 200.0;
  static const int RADAR_RINGS = 3;

  // ✅ Debug mode switch
  static const bool IS_DEBUG_MODE = true; // TODO: Environment variable

  // ✅ Helper getters
  static double get collectionRadius =>
      IS_DEBUG_MODE ? COLLECTION_RADIUS_DEBUG : COLLECTION_RADIUS_PROD;

  static bool get isDebugMode => IS_DEBUG_MODE;

  static String get debugModeLabel =>
      IS_DEBUG_MODE ? 'DEBUG (400m)' : 'PROD (2m)';
}
