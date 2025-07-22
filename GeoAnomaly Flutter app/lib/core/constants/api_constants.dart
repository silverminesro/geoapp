class ApiConstants {
  static const String baseUrl = 'http://95.217.17.177:8080/api/v1';

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';

  // Game endpoints
  static const String scanArea = '/game/scan-area';
  static const String nearbyZones = '/game/zones/nearby';
  static const String enterZone = '/game/zones/{id}/enter';
  static const String exitZone = '/game/zones/{id}/exit';
  static const String scanZone = '/game/zones/{id}/scan';
  static const String collectItem = '/game/zones/{id}/collect';

  // User endpoints
  static const String profile = '/user/profile';
  static const String inventory = '/user/inventory';
  static const String updateLocation = '/user/location';
}
