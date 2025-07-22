// lib/features/detector/providers/detection_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../map/models/location_model.dart';
import '../../map/services/location_service.dart';
import '../models/detection_state.dart';
import '../models/detector_model.dart';
import '../models/artifact_model.dart';
import '../models/detector_config.dart';
import '../services/detection_service.dart';
import '../services/radar_calculator.dart';

// ✅ Detection Service Provider
final detectionServiceProvider = Provider<DetectionService>((ref) {
  return DetectionService();
});

// ✅ Main Detection Provider
final detectionProvider = StateNotifierProvider.family<DetectionNotifier,
    DetectionState, DetectionProviderParams>(
  (ref, params) {
    final service = ref.watch(detectionServiceProvider);
    return DetectionNotifier(service, params.zoneId, params.detector);
  },
);

// ✅ Parameters for provider
class DetectionProviderParams {
  final String zoneId;
  final Detector detector;

  const DetectionProviderParams({
    required this.zoneId,
    required this.detector,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectionProviderParams &&
          runtimeType == other.runtimeType &&
          zoneId == other.zoneId &&
          detector.id == other.detector.id;

  @override
  int get hashCode => zoneId.hashCode ^ detector.id.hashCode;
}

// ✅ Detection State Notifier
class DetectionNotifier extends StateNotifier<DetectionState> {
  final DetectionService _detectionService;
  final String _zoneId;
  final Detector _detector;

  Timer? _locationTimer;
  Timer? _detectionTimer;
  List<DetectableItem> _allItems = [];
  bool _disposed = false; // ✅ Disposal check
  bool _locationUpdateInProgress = false; // ✅ Circuit breaker

  DetectionNotifier(this._detectionService, this._zoneId, this._detector)
      : super(const DetectionState()) {
    _initialize();
  }

  // ✅ ENHANCED Initialize detection system with real-time tracking
  Future<void> _initialize() async {
    if (_disposed) return;

    try {
      state =
          state.copyWith(isLoading: true, status: 'Initializing detector...');

      // Check location permission
      final hasPermission = await LocationService.requestLocationPermission();
      if (_disposed) return;

      if (!hasPermission) {
        state = state.copyWith(
          isLoading: false,
          hasLocationPermission: false,
          error: 'Location permission required for detector',
        );
        return;
      }

      state = state.copyWith(hasLocationPermission: true);

      // ✅ NEW: Start real-time location tracking
      try {
        await LocationService.startLocationTracking();
        print('✅ Real-time location tracking started for detector');

        // ✅ NEW: Add location listener for real-time updates
        LocationService.addLocationListener(_onLocationUpdate);

        state = state.copyWith(
          status: 'Real-time location tracking active...',
        );
      } catch (e) {
        print(
            '⚠️ Failed to start real-time tracking, falling back to periodic updates: $e');
        // Fallback to old timer-based approach
        Future.delayed(Duration(milliseconds: 2000), () {
          if (!_disposed) _startLocationTracking();
        });
      }

      // Load zone artifacts
      await _loadZoneArtifacts();
      if (_disposed) return;

      state = state.copyWith(
        isLoading: false,
        status:
            'Detector ready. Real-time tracking active. ${_allItems.length} items detected',
      );
    } catch (e) {
      if (_disposed) return;

      print('❌ Detection initialization failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize detector: $e',
      );
    }
  }

  // ✅ NEW: Real-time location update handler
  void _onLocationUpdate(LocationModel location) {
    if (_disposed || !mounted) return;

    print(
        '📍 Detection: Real-time location update - ${location.latitude}, ${location.longitude}');
    state = state.copyWith(currentLocation: location);

    // Update detection data immediately if scanning
    if (state.isScanning && _allItems.isNotEmpty) {
      _updateDetectionDataSafe();
    }
  }

  // ✅ Load artifacts from zone
  Future<void> _loadZoneArtifacts() async {
    if (_disposed) return;

    try {
      final result = await _detectionService.loadZoneArtifacts(_zoneId);
      if (_disposed) return;

      _allItems = result['allItems'] ?? [];
      final artifactCount = (result['artifacts'] as List? ?? []).length;
      final gearCount = (result['gear'] as List? ?? []).length;

      state = state.copyWith(
        allItems: _allItems,
        artifactCount: artifactCount,
        gearCount: gearCount,
      );

      print(
          '✅ Loaded ${_allItems.length} detectable items (${artifactCount} artifacts, ${gearCount} gear)');
    } catch (e) {
      if (_disposed) return;

      print('❌ Failed to load zone artifacts: $e');
      throw Exception('Failed to load detector data: $e');
    }
  }

  // ✅ FALLBACK: Timer-based location tracking (if real-time fails)
  void _startLocationTracking() {
    if (_disposed) return;

    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      Duration(seconds: 3), // ✅ Faster updates - reduced from 5 to 3 seconds
      (_) {
        if (!_disposed) _updateLocationSafe();
      },
    );

    // Initial location update
    Future.delayed(Duration(milliseconds: 500), () {
      if (!_disposed) _updateLocationSafe();
    });

    print('📍 Started fallback timer-based location tracking (3s intervals)');
  }

  // ✅ ENHANCED Safe location update with circuit breaker
  Future<void> _updateLocationSafe() async {
    if (_disposed || _locationUpdateInProgress) {
      return;
    }

    _locationUpdateInProgress = true;

    try {
      // ✅ Force fresh location for better accuracy
      final location = await LocationService.getCurrentLocation(
        useCache: false, // ✅ Changed to false for real-time accuracy
        allowFallback: true,
        forceRefresh: state.isScanning, // ✅ Force refresh when scanning
      );

      if (_disposed) return;

      state = state.copyWith(currentLocation: location);

      // If scanning, update detection data
      if (state.isScanning && _allItems.isNotEmpty && !_disposed) {
        _updateDetectionDataSafe();
      }
    } catch (e) {
      print('❌ Detection: Location update failed: $e');
      // Don't update error state for location failures during scanning
    } finally {
      _locationUpdateInProgress = false;
    }
  }

  // ✅ Start scanning
  void startScanning() {
    if (_disposed ||
        state.isScanning ||
        state.isLoading ||
        !state.hasLocationPermission) {
      return;
    }

    print('🔍 Starting scanning mode...');

    state = state.copyWith(
      isScanning: true,
      error: null,
      status: _allItems.isEmpty ? 'Scanning for artifacts...' : 'Scanning...',
    );

    // ✅ Get immediate location update when starting scan
    _updateLocationSafe();

    // Start detection updates
    _startDetectionUpdates();
  }

  // ✅ Stop scanning
  void stopScanning() {
    if (_disposed || !state.isScanning) return;

    print('🛑 Stopping scanning mode...');

    _detectionTimer?.cancel();

    state = state.copyWith(
      isScanning: false,
      signalStrength: 0.0,
      status: _allItems.isEmpty
          ? 'No items detected in this zone'
          : 'Detector ready. ${_allItems.length} items detected',
    );
  }

  // ✅ ENHANCED Start detection updates with faster intervals
  void _startDetectionUpdates() {
    if (_disposed) return;

    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(
      Duration(
          seconds:
              1), // ✅ Faster detection updates - reduced from 2 to 1 second
      (_) {
        if (!_disposed) _updateDetectionDataSafe();
      },
    );

    // Initial update immediately
    _updateDetectionDataSafe();

    print('🔍 Started detection updates (1s intervals)');
  }

  // ✅ Safe detection data update
  void _updateDetectionDataSafe() {
    if (_disposed ||
        !state.isScanning ||
        state.currentLocation == null ||
        _allItems.isEmpty) {
      return;
    }

    try {
      final detectionData = _detectionService.calculateDetectionData(
        _allItems,
        state.currentLocation,
        _detector,
      );

      if (_disposed) return;

      final updatedItems =
          detectionData['updatedItems'] as List<DetectableItem>;
      final closestItem = detectionData['closestItem'] as DetectableItem?;
      final signalStrength = detectionData['signalStrength'] as double;
      final distance = detectionData['distance'] as double;
      final direction = detectionData['direction'] as String;

      // Filter items within detector range
      final detectableItems = updatedItems.where((item) {
        final itemDistance = item.distanceFromPlayer ?? double.infinity;
        return itemDistance <= _detector.maxRangeMeters;
      }).toList();

      state = state.copyWith(
        allItems: updatedItems,
        detectableItems: detectableItems,
        closestItem: closestItem,
        signalStrength: signalStrength,
        distance: distance,
        direction: direction,
        status: _formatScanningStatus(detectableItems.length, signalStrength),
      );
    } catch (e) {
      if (_disposed) return;

      print('❌ Detection update failed: $e');
      state = state.copyWith(
        error: 'Detection update failed: $e',
        isScanning: false,
      );
    }
  }

  // ✅ Format scanning status message
  String _formatScanningStatus(int detectableCount, double signalStrength) {
    if (detectableCount == 0) {
      return 'Scanning... No items in range';
    }

    if (signalStrength > 0.8) {
      return 'Strong signal detected! ${detectableCount} items in range';
    } else if (signalStrength > 0.4) {
      return 'Signal detected. ${detectableCount} items in range';
    } else if (signalStrength > 0.0) {
      return 'Weak signal. ${detectableCount} items in range';
    }

    return 'Scanning... ${detectableCount} items in range';
  }

  // ✅ ENHANCED Collect item with immediate location check
  Future<void> collectItem(DetectableItem item) async {
    if (_disposed || state.isCollecting || state.currentLocation == null)
      return;

    try {
      // ✅ Get fresh location before collection attempt
      final currentLocation = await LocationService.getCurrentLocation(
        forceRefresh: true,
        allowFallback: false,
      );

      state = state.copyWith(
        isCollecting: true,
        status: 'Collecting ${item.name}...',
        currentLocation: currentLocation,
      );

      await _detectionService.collectItem(
        _zoneId,
        item,
        currentLocation,
      );

      if (_disposed) return;

      // Remove collected item from lists
      final updatedAllItems = _allItems.where((i) => i.id != item.id).toList();
      final updatedDetectableItems =
          state.detectableItems.where((i) => i.id != item.id).toList();

      _allItems = updatedAllItems;

      state = state.copyWith(
        isCollecting: false,
        allItems: updatedAllItems,
        detectableItems: updatedDetectableItems,
        closestItem:
            state.closestItem?.id == item.id ? null : state.closestItem,
        status:
            'Collected ${item.name}! ${updatedAllItems.length} items remaining',
      );

      print('✅ Successfully collected: ${item.name}');
    } catch (e) {
      if (_disposed) return;

      print('❌ Collection failed: $e');
      state = state.copyWith(
        isCollecting: false,
        error: e.toString(),
        status: 'Collection failed: $e',
      );
    }
  }

  // ✅ Clear error
  void clearError() {
    if (_disposed) return;
    state = state.copyWith(error: null);
  }

  // ✅ ENHANCED Refresh detection data
  Future<void> refresh() async {
    if (_disposed) return;

    try {
      state = state.copyWith(isLoading: true, error: null);

      // ✅ Force fresh location on refresh
      await LocationService.refreshLocation();

      await _loadZoneArtifacts();

      if (!_disposed && state.currentLocation != null && state.isScanning) {
        _updateDetectionDataSafe();
      }

      if (_disposed) return;

      state = state.copyWith(
        isLoading: false,
        status: 'Refreshed. ${_allItems.length} items detected',
      );
    } catch (e) {
      if (_disposed) return;

      state = state.copyWith(
        isLoading: false,
        error: 'Refresh failed: $e',
      );
    }
  }

  // ✅ Check if notifier is still mounted
  bool get mounted => !_disposed;

  // ✅ ENHANCED Dispose method
  @override
  void dispose() {
    print('🗑️ Disposing DetectionNotifier for zone: $_zoneId');
    _disposed = true;

    // ✅ Remove location listener
    try {
      LocationService.removeLocationListener(_onLocationUpdate);
    } catch (e) {
      print('⚠️ Error removing location listener: $e');
    }

    // Cancel timers
    _locationTimer?.cancel();
    _detectionTimer?.cancel();

    // Dispose service
    _detectionService.dispose();

    super.dispose();
  }
}

// ✅ Convenience providers for easy access
final isDetectionLoadingProvider =
    Provider.family<bool, DetectionProviderParams>((ref, params) {
  return ref.watch(detectionProvider(params)).isLoading;
});

final isDetectionScanningProvider =
    Provider.family<bool, DetectionProviderParams>((ref, params) {
  return ref.watch(detectionProvider(params)).isScanning;
});

final detectionStatusProvider =
    Provider.family<String, DetectionProviderParams>((ref, params) {
  final state = ref.watch(detectionProvider(params));
  return state.statusMessage;
});

final detectableItemsProvider =
    Provider.family<List<DetectableItem>, DetectionProviderParams>(
        (ref, params) {
  return ref.watch(detectionProvider(params)).detectableItems;
});

final closestItemProvider =
    Provider.family<DetectableItem?, DetectionProviderParams>((ref, params) {
  return ref.watch(detectionProvider(params)).closestItem;
});

final signalStrengthProvider =
    Provider.family<double, DetectionProviderParams>((ref, params) {
  return ref.watch(detectionProvider(params)).signalStrength;
});

// ✅ ENHANCED Radar positions provider
final radarPositionsProvider =
    Provider.family<List<Map<String, dynamic>>, DetectionProviderParams>(
        (ref, params) {
  final state = ref.watch(detectionProvider(params));
  final items = state.detectableItems;

  final List<Map<String, dynamic>> radarItems = [];

  for (final item in items.take(DetectorConfig.MAX_RADAR_ITEMS)) {
    if (item.distanceFromPlayer != null && item.bearingFromPlayer != null) {
      final position = RadarCalculator.calculateRadarPosition(
        item.distanceFromPlayer!,
        item.bearingFromPlayer!,
        params.detector.maxRangeMeters,
      );

      radarItems.add({
        'item': item,
        'x': position['x']!,
        'y': position['y']!,
        'distance': item.distanceFromPlayer!,
        'bearing': item.bearingFromPlayer!,
        'isVeryClose': item.isVeryClose,
        'isClose': item.isClose,
      });
    }
  }

  return radarItems;
});

// ✅ NEW: Location tracking status provider
final locationTrackingStatusProvider = Provider<String>((ref) {
  return LocationService.locationStatus;
});

// ✅ NEW: Location info provider for debugging
final locationInfoProvider = Provider<Map<String, dynamic>>((ref) {
  return LocationService.getLocationInfo();
});
