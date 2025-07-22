import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/location_model.dart';
import 'dart:async';

class LocationService {
  // ✅ GPS Cache variables
  static LocationModel? _cachedLocation;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheTimeout = Duration(minutes: 2);

  // ✅ Distance and accuracy filters
  static const double _minDistanceMeters = 10.0;
  static const double _maxAccuracyMeters = 50.0;

  // ✅ Real-time tracking
  static Position? _lastKnownPosition;
  static DateTime? _lastLocationUpdate;
  static StreamSubscription<Position>? _locationSubscription;
  static Stream<Position>? _positionStream;

  // ✅ Location update frequency control
  static const Duration _staleLocationTimeout = Duration(seconds: 45);

  // ✅ Circuit breaker for updates
  static bool _isUpdating = false;

  // ✅ Callbacks for real-time updates
  static final List<Function(LocationModel)> _locationListeners = [];

  static Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        await openAppSettings();
        return false;
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      print('❌ Error requesting location permission: $e');
      return false;
    }
  }

  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('❌ Error checking location service: $e');
      return false;
    }
  }

  // ✅ ENHANCED getCurrentLocation with multiple optimization layers
  static Future<LocationModel> getCurrentLocation({
    bool useCache = true,
    bool allowFallback = true,
    bool forceRefresh = false,
    Duration? customTimeout,
  }) async {
    // ✅ Prevent concurrent updates
    if (_isUpdating && !forceRefresh) {
      print('⚠️ Location update already in progress, using cache');
      if (_cachedLocation != null) {
        return _cachedLocation!;
      }
    }

    try {
      _isUpdating = true;

      // ✅ Force refresh bypasses all caching
      if (forceRefresh) {
        print('🔄 Force refreshing GPS location...');
        return await _getFreshLocation(allowFallback, customTimeout);
      }

      // ✅ Check real-time tracking first
      if (_locationSubscription != null && !_locationSubscription!.isPaused) {
        if (_lastKnownPosition != null && _isLocationRecent()) {
          print('📍 Using real-time tracked location');
          final location = LocationModel(
            latitude: _lastKnownPosition!.latitude,
            longitude: _lastKnownPosition!.longitude,
            timestamp: DateTime.now(),
            accuracy: _lastKnownPosition!.accuracy,
          );
          _updateCache(location);
          return location;
        }
      }

      // ✅ Check cache validity
      if (useCache && _isCacheValid()) {
        print('📍 Using cached GPS location (age: ${_getCacheAge()})');
        return _cachedLocation!;
      }

      // ✅ Check distance filter
      if (_cachedLocation != null && useCache) {
        try {
          final fresh = await _getFreshLocation(false, Duration(seconds: 5));
          final distance = await distanceBetween(
            _cachedLocation!.latitude,
            _cachedLocation!.longitude,
            fresh.latitude,
            fresh.longitude,
          );

          if (distance < _minDistanceMeters) {
            print('📍 Movement too small: ${distance.toInt()}m, using cached');
            return _cachedLocation!;
          }

          print(
              '📍 Significant movement: ${distance.toInt()}m, updating cache');
          _updateCache(fresh);
          return fresh;
        } catch (e) {
          print('⚠️ Distance check failed: $e');
        }
      }

      // ✅ Get fresh location
      return await _getFreshLocation(allowFallback, customTimeout);
    } catch (e) {
      print('❌ getCurrentLocation error: $e');

      if (allowFallback) {
        return _getFallbackLocation();
      }

      rethrow;
    } finally {
      _isUpdating = false;
    }
  }

  // ✅ Get fresh GPS location with enhanced error handling
  static Future<LocationModel> _getFreshLocation(
    bool allowFallback,
    Duration? timeout,
  ) async {
    try {
      // Check permissions
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('Location permissions denied');
      }

      // Check service
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled');
      }

      print('📍 Getting fresh GPS location...');

      // ✅ Get position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout ?? Duration(seconds: 10),
      );

      // ✅ Accuracy filter
      if (position.accuracy > _maxAccuracyMeters) {
        print(
            '⚠️ GPS accuracy too low: ${position.accuracy}m (max: ${_maxAccuracyMeters}m)');

        if (allowFallback && _cachedLocation != null) {
          print('📍 Using cached location due to poor accuracy');
          return _cachedLocation!;
        }
      }

      // ✅ Create location model
      final location = LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        accuracy: position.accuracy,
      );

      // ✅ Update cache and tracking
      _updateCache(location);
      _lastKnownPosition = position;
      _lastLocationUpdate = DateTime.now();

      // ✅ Notify listeners
      _notifyListeners(location);

      print(
          '✅ Fresh GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} (±${position.accuracy.toInt()}m)');

      return location;
    } catch (e) {
      print('❌ Fresh location failed: $e');

      if (allowFallback && _cachedLocation != null) {
        print('📍 Using cached location as fallback');
        return _cachedLocation!;
      }

      if (allowFallback) {
        return _getFallbackLocation();
      }

      throw Exception('Unable to get location: $e');
    }
  }

  // ✅ Start real-time location tracking
  static Future<void> startLocationTracking() async {
    try {
      print('📍 Starting real-time location tracking...');

      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('Location permission denied');
      }

      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled');
      }

      // ✅ Stop existing stream
      await stopLocationTracking();

      // ✅ Create optimized position stream
      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Update every 5 meters
          timeLimit: Duration(seconds: 10),
        ),
      );

      // ✅ Listen to position updates
      _locationSubscription = _positionStream!.listen(
        (Position position) {
          print(
              '📍 Real-time update: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} (±${position.accuracy.toInt()}m)');

          _lastKnownPosition = position;
          _lastLocationUpdate = DateTime.now();

          final locationModel = LocationModel(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: DateTime.now(),
            accuracy: position.accuracy,
          );

          // ✅ Update cache
          _updateCache(locationModel);

          // ✅ Notify listeners
          _notifyListeners(locationModel);
        },
        onError: (error) {
          print('❌ Location stream error: $error');

          // ✅ Restart stream after error with delay
          Future.delayed(Duration(seconds: 5), () {
            if (_locationSubscription?.isPaused != false) {
              startLocationTracking();
            }
          });
        },
      );

      print('✅ Real-time location tracking started');
    } catch (e) {
      print('❌ Failed to start location tracking: $e');
      rethrow;
    }
  }

  // ✅ Stop location tracking
  static Future<void> stopLocationTracking() async {
    print('🛑 Stopping location tracking...');
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _positionStream = null;
  }

  // ✅ Location listener management
  static void addLocationListener(Function(LocationModel) listener) {
    if (!_locationListeners.contains(listener)) {
      _locationListeners.add(listener);
      print('📍 Added location listener. Total: ${_locationListeners.length}');
    }
  }

  // ✅ FIXED: Auto-stop tracking when no listeners
  static void removeLocationListener(Function(LocationModel) listener) {
    _locationListeners.remove(listener);
    print('📍 Removed location listener. Total: ${_locationListeners.length}');

    // ✅ FIXED: Stop tracking if no more listeners
    if (_locationListeners.isEmpty) {
      print('📍 No more listeners, stopping location tracking');
      stopLocationTracking();
    }
  }

  // ✅ Cache management
  static void _updateCache(LocationModel location) {
    _cachedLocation = location;
    _cacheTimestamp = DateTime.now();
  }

  static bool _isCacheValid() {
    return _cachedLocation != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTimeout;
  }

  static String _getCacheAge() {
    if (_cacheTimestamp == null) return 'no cache';
    final age = DateTime.now().difference(_cacheTimestamp!);
    if (age.inSeconds < 60) return '${age.inSeconds}s';
    return '${age.inMinutes}m ${age.inSeconds % 60}s';
  }

  static bool _isLocationRecent() {
    return _lastLocationUpdate != null &&
        DateTime.now().difference(_lastLocationUpdate!) < _staleLocationTimeout;
  }

  // ✅ Notify all listeners
  static void _notifyListeners(LocationModel location) {
    for (final listener in List.from(_locationListeners)) {
      try {
        listener(location);
      } catch (e) {
        print('⚠️ Location listener error: $e');
      }
    }
  }

  // ✅ Fallback location (Bratislava)
  static LocationModel _getFallbackLocation() {
    print('📍 Using fallback location (Bratislava)');
    final fallback = LocationModel(
      latitude: 48.1482,
      longitude: 17.1067,
      timestamp: DateTime.now(),
      accuracy: 1000.0, // Mark as inaccurate
    );
    _updateCache(fallback);
    return fallback;
  }

  // ✅ Utility methods
  static Future<double> distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) async {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // ✅ Stream for location updates (compatibility)
  static Stream<LocationModel> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).map((position) => LocationModel(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
          accuracy: position.accuracy,
        ));
  }

  // ✅ Force location refresh
  static Future<LocationModel> refreshLocation() async {
    return getCurrentLocation(forceRefresh: true, allowFallback: true);
  }

  // ✅ Clear all caches
  static void clearCache() {
    _cachedLocation = null;
    _cacheTimestamp = null;
    _lastKnownPosition = null;
    _lastLocationUpdate = null;
    print('🗑️ All location caches cleared');
  }

  // ✅ Status getters
  static Duration? get locationAge {
    if (_cacheTimestamp == null) return null;
    return DateTime.now().difference(_cacheTimestamp!);
  }

  static bool get isTrackingActive {
    return _locationSubscription != null && !_locationSubscription!.isPaused;
  }

  static String get locationStatus {
    if (!isTrackingActive) return 'Tracking Inactive';
    if (_lastLocationUpdate == null) return 'No Location';

    final age = DateTime.now().difference(_lastLocationUpdate!);
    if (age.inSeconds < 15) return 'Real-time';
    if (age.inSeconds < 30) return 'Recent';
    if (age.inMinutes < 2) return 'Cached';
    return 'Stale';
  }

  static LocationModel? get lastKnownLocation => _cachedLocation;

  // ✅ Debugging info
  static Map<String, dynamic> getLocationInfo() {
    return {
      'has_cached_location': _cachedLocation != null,
      'cache_timestamp': _cacheTimestamp?.toIso8601String(),
      'cache_age_seconds': locationAge?.inSeconds,
      'is_tracking': isTrackingActive,
      'status': locationStatus,
      'listeners_count': _locationListeners.length,
      'last_accuracy': _cachedLocation?.accuracy,
      'coordinates': _cachedLocation != null
          ? '${_cachedLocation!.latitude.toStringAsFixed(6)}, ${_cachedLocation!.longitude.toStringAsFixed(6)}'
          : 'none',
      'is_updating': _isUpdating,
      'last_position_time': _lastLocationUpdate?.toIso8601String(),
    };
  }
}
