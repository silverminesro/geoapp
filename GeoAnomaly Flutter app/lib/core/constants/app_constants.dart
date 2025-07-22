class AppConstants {
  // App Info
  static const String appName = 'GeoAnomaly';
  static const String appVersion = '0.0.1';

  // Location
  static const double defaultLatitude = 48.1482;
  static const double defaultLongitude = 17.1067; // Bratislava
  static const double locationUpdateDistanceFilter = 10; // meters

  // Game Settings
  static const int scanCooldownMinutes = 5;
  static const int collectCooldownSeconds = 30;
  static const double zoneDiscoveryRadius = 5000; // meters

  // UI
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;
}
