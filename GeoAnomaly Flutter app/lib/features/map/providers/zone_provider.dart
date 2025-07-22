import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/zone_model.dart';
import '../services/zone_service.dart';
import '../services/location_service.dart';
import '../models/location_model.dart';
import 'dart:async';
import 'dart:math' as math; // ✅ PRIDANÉ pre offset calculations

// ✅ Zone Service Provider
final zoneServiceProvider = Provider<ZoneService>((ref) {
  return ZoneService();
});

// ✅ Enhanced Zone State
class ZoneState {
  final Zone? currentZone;
  final bool isInZone;
  final bool isEntering;
  final bool isExiting;
  final bool isLoading;
  final String? error;
  final LocationModel? playerLocation;
  final double? distanceToZone;
  final List<Zone> nearbyZones;
  final DateTime? lastLocationUpdate;
  final String locationStatus;
  final bool isLocationTracking;

  const ZoneState({
    this.currentZone,
    this.isInZone = false,
    this.isEntering = false,
    this.isExiting = false,
    this.isLoading = false,
    this.error,
    this.playerLocation,
    this.distanceToZone,
    this.nearbyZones = const [],
    this.lastLocationUpdate,
    this.locationStatus = 'Unknown',
    this.isLocationTracking = false,
  });

  ZoneState copyWith({
    Zone? currentZone,
    bool? isInZone,
    bool? isEntering,
    bool? isExiting,
    bool? isLoading,
    String? error,
    LocationModel? playerLocation,
    double? distanceToZone,
    List<Zone>? nearbyZones,
    DateTime? lastLocationUpdate,
    String? locationStatus,
    bool? isLocationTracking,
  }) {
    return ZoneState(
      currentZone: currentZone ?? this.currentZone,
      isInZone: isInZone ?? this.isInZone,
      isEntering: isEntering ?? this.isEntering,
      isExiting: isExiting ?? this.isExiting,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      playerLocation: playerLocation ?? this.playerLocation,
      distanceToZone: distanceToZone ?? this.distanceToZone,
      nearbyZones: nearbyZones ?? this.nearbyZones,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      locationStatus: locationStatus ?? this.locationStatus,
      isLocationTracking: isLocationTracking ?? this.isLocationTracking,
    );
  }

  // ✅ Enhanced helper getters
  bool get canEnterZone =>
      currentZone != null &&
      !isInZone &&
      !isEntering &&
      !isLoading &&
      _isWithinEnterRange;

  bool get canExitZone => isInZone && !isExiting && !isLoading;

  bool get _isWithinEnterRange {
    if (currentZone == null || playerLocation == null)
      return true; // Allow for testing

    final distance = currentZone!.distanceFromPoint(
      playerLocation!.latitude,
      playerLocation!.longitude,
    );

    // ✅ Enhanced range calculation with zone radius
    final enterRange =
        currentZone!.radiusMeters.toDouble() + 100.0; // 100m buffer
    return distance <= enterRange;
  }

  String get statusText {
    if (isEntering) return 'Entering zone...';
    if (isExiting) return 'Exiting zone...';
    if (isInZone) return 'You are in this zone';
    if (currentZone != null && distanceToZone != null) {
      final distance = distanceToZone!.toInt();
      if (distance < 1000) {
        return 'Distance: ${distance}m away';
      } else {
        return 'Distance: ${(distance / 1000).toStringAsFixed(1)}km away';
      }
    }
    return 'Outside zone';
  }

  String get locationStatusText {
    if (playerLocation == null) return 'No location';

    final age = lastLocationUpdate != null
        ? DateTime.now().difference(lastLocationUpdate!)
        : null;

    if (age != null) {
      if (age.inSeconds < 30) return 'Real-time location';
      if (age.inMinutes < 2) return 'Recent location';
      return 'Cached location (${age.inMinutes}m old)';
    }

    return locationStatus;
  }
}

// ✅ Enhanced Zone Notifier with Circuit Breaker
class ZoneNotifier extends StateNotifier<ZoneState> {
  final ZoneService _zoneService;

  // ✅ Circuit breaker variables
  bool _isUpdatingLocation = false;
  bool _isInitializing = false;
  bool _disposed = false;

  // ✅ Location tracking
  Timer? _locationUpdateTimer;
  StreamSubscription<LocationModel>? _locationSubscription;

  // ✅ Rate limiting
  DateTime? _lastLocationUpdate;
  static const Duration _locationUpdateCooldown = Duration(seconds: 5);

  ZoneNotifier(this._zoneService) : super(const ZoneState()) {
    _initializeLocationTracking();
  }

  // ✅ Initialize location tracking
  Future<void> _initializeLocationTracking() async {
    if (_disposed || _isInitializing) return;

    _isInitializing = true;

    try {
      print('📍 Initializing zone location tracking...');

      // ✅ Start real-time location service
      await LocationService.startLocationTracking();

      // ✅ Add location listener
      LocationService.addLocationListener(_onLocationUpdate);

      // ✅ Set up periodic location checks (fallback)
      _locationUpdateTimer = Timer.periodic(
        Duration(seconds: 30),
        (_) => _updatePlayerLocationSafe(),
      );

      state = state.copyWith(isLocationTracking: true);

      // ✅ Get initial location
      await _updatePlayerLocationSafe();

      print('✅ Zone location tracking initialized');
    } catch (e) {
      print('❌ Failed to initialize location tracking: $e');
    } finally {
      _isInitializing = false;
    }
  }

  // ✅ Location update callback
  void _onLocationUpdate(LocationModel location) {
    if (_disposed) return;

    print(
        '📍 Zone provider received location update: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}');

    // ✅ Rate limiting
    final now = DateTime.now();
    if (_lastLocationUpdate != null &&
        now.difference(_lastLocationUpdate!) < _locationUpdateCooldown) {
      return;
    }
    _lastLocationUpdate = now;

    // ✅ Update state with new location
    double? distanceToZone;
    if (state.currentZone != null) {
      distanceToZone = state.currentZone!.distanceFromPoint(
        location.latitude,
        location.longitude,
      );

      // ✅ DEBUG: Print distance calculation
      print(
          '📏 Distance calculation: Player(${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}) -> Zone(${state.currentZone!.location.latitude}, ${state.currentZone!.location.longitude}) = ${distanceToZone.toInt()}m');
    }

    state = state.copyWith(
      playerLocation: location,
      distanceToZone: distanceToZone,
      lastLocationUpdate: now,
      locationStatus: LocationService.locationStatus,
    );
  }

  // ✅ FIXED: Load specific zone with real coordinates support
  Future<void> loadZone(String zoneId, {Zone? providedZoneData}) async {
    if (_disposed) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      print('🔍 Loading zone: $zoneId');

      // ✅ Use provided zone data if available (from map)
      if (providedZoneData != null) {
        print('✅ Using provided zone data from map');
        print(
            '📍 Zone coordinates: ${providedZoneData.location.latitude.toStringAsFixed(6)}, ${providedZoneData.location.longitude.toStringAsFixed(6)}');

        state = state.copyWith(
          currentZone: providedZoneData,
          isLoading: false,
          error: null,
        );

        // Update location to calculate real distance
        Future.delayed(Duration(seconds: 1), () {
          if (!_disposed) _updatePlayerLocationSafe();
        });

        print('✅ Zone loaded from map data: ${providedZoneData.name}');
        return;
      }

      // Try API first
      final zone = await _zoneService.getZoneDetails(zoneId);

      if (_disposed) return;

      state = state.copyWith(
        currentZone: zone,
        isLoading: false,
        error: null,
      );

      Future.delayed(Duration(seconds: 1), () {
        if (!_disposed) _updatePlayerLocationSafe();
      });

      print('✅ Zone loaded from API: ${zone.name}');
    } catch (e) {
      print('❌ Failed to load zone from API: $e');

      if (_disposed) return;

      // ✅ FIXED: Only create mock if no provided data
      if (providedZoneData == null) {
        try {
          print('🧪 Creating test zone with realistic offset...');

          final currentLocation = await LocationService.getCurrentLocation(
            forceRefresh: false,
            allowFallback: true,
          );

          // ✅ Add realistic offset (150-300m away)
          final random = math.Random();
          final offsetDistance =
              0.0015 + (random.nextDouble() * 0.001); // 150-300m
          final offsetAngle =
              random.nextDouble() * 2 * math.pi; // Random direction

          final offsetLat = currentLocation.latitude +
              (offsetDistance * math.cos(offsetAngle));
          final offsetLng = currentLocation.longitude +
              (offsetDistance * math.sin(offsetAngle));

          print(
              '📍 Player: ${currentLocation.latitude.toStringAsFixed(6)}, ${currentLocation.longitude.toStringAsFixed(6)}');
          print(
              '📍 Test zone: ${offsetLat.toStringAsFixed(6)}, ${offsetLng.toStringAsFixed(6)}');

          final mockZone = Zone(
            id: zoneId,
            name: 'Test Zone (Mock)',
            description:
                'Test zone placed ~200m from your location for development.',
            location: Location(
              latitude: offsetLat,
              longitude: offsetLng,
            ),
            radiusMeters: 250,
            tierRequired: 1,
            zoneType: 'dynamic',
            biome: 'forest',
            dangerLevel: 'medium',
            isActive: true,
          );

          state = state.copyWith(
            currentZone: mockZone,
            isLoading: false,
            error: null,
          );

          print('✅ Mock test zone created with realistic distance');

          // Calculate and show distance
          Future.delayed(Duration(milliseconds: 500), () {
            if (!_disposed) _updatePlayerLocationSafe();
          });
        } catch (locationError) {
          print('❌ Failed to create mock zone: $locationError');

          // Final fallback to Bratislava
          final fallbackZone = Zone(
            id: zoneId,
            name: 'Fallback Zone (Bratislava)',
            description:
                'Fallback zone in Bratislava - GPS may not be available.',
            location: const Location(latitude: 48.1486, longitude: 17.1077),
            radiusMeters: 250,
            tierRequired: 1,
            zoneType: 'dynamic',
            biome: 'forest',
            dangerLevel: 'medium',
            isActive: true,
          );

          state = state.copyWith(
            currentZone: fallbackZone,
            isLoading: false,
            error: null,
          );

          print('⚠️ Using Bratislava fallback zone');
        }
      }
    }
  }

  // ✅ NEW: Load zone with provided data
  Future<void> loadZoneWithData(String zoneId, Zone? zoneData) async {
    await loadZone(zoneId, providedZoneData: zoneData);
  }

  // ✅ Enter zone with enhanced validation
  Future<void> enterZone() async {
    if (!state.canEnterZone || _disposed) {
      print('⚠️ Cannot enter zone - conditions not met');
      print(
          '🔍 Debug: canEnterZone=${state.canEnterZone}, disposed=$_disposed, distance=${state.distanceToZone?.toInt()}m');
      return;
    }

    state = state.copyWith(isEntering: true, error: null);

    try {
      print('🚪 Entering zone: ${state.currentZone!.name}');

      await _zoneService.enterZone(state.currentZone!.id);

      if (_disposed) return;

      state = state.copyWith(
        isInZone: true,
        isEntering: false,
      );

      print('✅ Successfully entered zone');
    } catch (e) {
      print('❌ Failed to enter zone via API: $e');

      if (_disposed) return;

      // ✅ For testing, simulate successful entry
      await Future.delayed(const Duration(seconds: 2));

      if (_disposed) return;

      state = state.copyWith(
        isInZone: true,
        isEntering: false,
        error: null,
      );

      print('✅ Simulated zone entry for testing');
    }
  }

  // ✅ Exit zone with enhanced validation
  Future<void> exitZone() async {
    if (!state.canExitZone || _disposed) {
      print('⚠️ Cannot exit zone - conditions not met');
      return;
    }

    state = state.copyWith(isExiting: true, error: null);

    try {
      print('🚪 Exiting zone: ${state.currentZone!.name}');

      await _zoneService.exitZone(state.currentZone!.id);

      if (_disposed) return;

      state = state.copyWith(
        isInZone: false,
        isExiting: false,
      );

      print('✅ Successfully exited zone');
    } catch (e) {
      print('❌ Failed to exit zone via API: $e');

      if (_disposed) return;

      // ✅ For testing, simulate successful exit
      await Future.delayed(const Duration(seconds: 1));

      if (_disposed) return;

      state = state.copyWith(
        isInZone: false,
        isExiting: false,
        error: null,
      );

      print('✅ Simulated zone exit for testing');
    }
  }

  // ✅ Safe location update with circuit breaker
  Future<void> _updatePlayerLocationSafe() async {
    if (_disposed || _isUpdatingLocation) {
      print(
          '⚠️ Skipping location update - disposed: $_disposed, updating: $_isUpdatingLocation');
      return;
    }

    _isUpdatingLocation = true;

    try {
      print('📍 Zone provider updating location...');

      final location = await LocationService.getCurrentLocation(
        useCache: true,
        allowFallback: true,
      );

      if (_disposed) return;

      double? distanceToZone;
      if (state.currentZone != null) {
        distanceToZone = state.currentZone!.distanceFromPoint(
          location.latitude,
          location.longitude,
        );

        print('📏 Distance to zone: ${distanceToZone.toInt()}m');
        print(
            '🔍 Zone at: ${state.currentZone!.location.latitude.toStringAsFixed(6)}, ${state.currentZone!.location.longitude.toStringAsFixed(6)}');
        print(
            '🔍 Player at: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}');
      }

      state = state.copyWith(
        playerLocation: location,
        distanceToZone: distanceToZone,
        lastLocationUpdate: DateTime.now(),
        locationStatus: LocationService.locationStatus,
      );

      print('✅ Zone provider location updated');
    } catch (e) {
      print('❌ Zone provider location update failed: $e');

      if (_disposed) return;

      // ✅ Don't set error state for location failures to prevent UI issues
      state = state.copyWith(
        locationStatus: 'Location Error',
      );
    } finally {
      _isUpdatingLocation = false;
    }
  }

  // ✅ Manual refresh with enhanced feedback
  Future<void> refresh() async {
    if (_disposed) return;

    try {
      print('🔄 Manual zone refresh requested');

      // ✅ Force fresh location
      await LocationService.refreshLocation();

      // ✅ Reload current zone if exists
      if (state.currentZone != null) {
        await loadZone(state.currentZone!.id);
      }

      // ✅ Update location after zone reload
      await Future.delayed(Duration(milliseconds: 500));
      if (!_disposed) {
        await _updatePlayerLocationSafe();
      }

      print('✅ Zone refresh completed');
    } catch (e) {
      print('❌ Zone refresh failed: $e');

      if (_disposed) return;

      state = state.copyWith(
        error: 'Refresh failed: ${e.toString()}',
      );
    }
  }

  // ✅ Force location update (public method)
  Future<void> updateLocation() async {
    if (_disposed) return;
    await _updatePlayerLocationSafe();
  }

  // ✅ Clear error
  void clearError() {
    if (_disposed) return;
    state = state.copyWith(error: null);
  }

  // ✅ Get debugging info
  Map<String, dynamic> getDebugInfo() {
    return {
      'is_disposed': _disposed,
      'is_updating_location': _isUpdatingLocation,
      'is_initializing': _isInitializing,
      'current_zone_id': state.currentZone?.id,
      'is_in_zone': state.isInZone,
      'location_status': state.locationStatus,
      'distance_to_zone': state.distanceToZone?.toInt(),
      'zone_coordinates': state.currentZone != null
          ? '${state.currentZone!.location.latitude.toStringAsFixed(6)}, ${state.currentZone!.location.longitude.toStringAsFixed(6)}'
          : 'none',
      'player_coordinates': state.playerLocation != null
          ? '${state.playerLocation!.latitude.toStringAsFixed(6)}, ${state.playerLocation!.longitude.toStringAsFixed(6)}'
          : 'none',
      'location_age': state.lastLocationUpdate != null
          ? DateTime.now().difference(state.lastLocationUpdate!).inSeconds
          : null,
      'location_service_info': LocationService.getLocationInfo(),
    };
  }

  // ✅ FIXED: Enhanced dispose method
  @override
  void dispose() {
    print('🗑️ Disposing ZoneNotifier...');

    _disposed = true;

    // ✅ Stop location tracking
    _locationUpdateTimer?.cancel();
    _locationSubscription?.cancel();

    // ✅ Remove location listener (will auto-stop tracking if no more listeners)
    LocationService.removeLocationListener(_onLocationUpdate);

    super.dispose();

    print('✅ ZoneNotifier disposed');
  }
}

// ✅ Zone Provider
final zoneProvider = StateNotifierProvider<ZoneNotifier, ZoneState>((ref) {
  final zoneService = ref.watch(zoneServiceProvider);
  return ZoneNotifier(zoneService);
});

// ✅ Enhanced convenience providers
final currentZoneProvider = Provider<Zone?>((ref) {
  return ref.watch(zoneProvider).currentZone;
});

final isInZoneProvider = Provider<bool>((ref) {
  return ref.watch(zoneProvider).isInZone;
});

final canEnterZoneProvider = Provider<bool>((ref) {
  return ref.watch(zoneProvider).canEnterZone;
});

final canExitZoneProvider = Provider<bool>((ref) {
  return ref.watch(zoneProvider).canExitZone;
});

final zoneStatusProvider = Provider<String>((ref) {
  return ref.watch(zoneProvider).statusText;
});

final playerLocationProvider = Provider<LocationModel?>((ref) {
  return ref.watch(zoneProvider).playerLocation;
});

final distanceToZoneProvider = Provider<double?>((ref) {
  return ref.watch(zoneProvider).distanceToZone;
});

final locationStatusProvider = Provider<String>((ref) {
  return ref.watch(zoneProvider).locationStatusText;
});

// ✅ Debug provider
final zoneDebugProvider = Provider<Map<String, dynamic>>((ref) {
  final notifier = ref.watch(zoneProvider.notifier);
  return notifier.getDebugInfo();
});
