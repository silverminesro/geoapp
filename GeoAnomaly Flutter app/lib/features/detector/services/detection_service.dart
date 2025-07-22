// lib/features/detector/services/detection_service.dart
import 'dart:async';
import 'dart:math' as math;
import '../../map/models/location_model.dart';
import '../../map/services/zone_service.dart';
import '../../map/services/location_service.dart';
import '../models/detector_model.dart';
import '../models/artifact_model.dart';
import '../models/detector_config.dart';

class DetectionService {
  final ZoneService _zoneService = ZoneService();

  // Timer controllers
  Timer? _locationTimer;
  Timer? _detectionTimer;

  // Callbacks for UI updates
  Function(LocationModel)? onLocationUpdate;
  Function(List<DetectableItem>, DetectableItem?)? onDetectionUpdate;
  Function(String, {bool isError})? onStatusUpdate;

  // ✅ Load artifacts from zone
  Future<Map<String, dynamic>> loadZoneArtifacts(String zoneId) async {
    try {
      print('🔍🎯 Loading zone artifacts for detector: $zoneId');

      final response = await _zoneService.getZoneArtifacts(zoneId);

      final artifacts = <DetectableItem>[];
      final gear = <DetectableItem>[];

      // ✅ ENHANCED: Tag items with their source type during loading
      if (response['artifacts'] != null) {
        artifacts.addAll(
          (response['artifacts'] as List).map<DetectableItem>((json) {
            // ✅ Force mark as artifact
            final modifiedJson = Map<String, dynamic>.from(json);
            modifiedJson['source_type'] = 'artifact';
            return DetectableItem.fromJson(modifiedJson);
          }).where((item) => item.canBeDetected),
        );
      }

      if (response['gear'] != null) {
        gear.addAll(
          (response['gear'] as List).map<DetectableItem>((json) {
            // ✅ Force mark as gear
            final modifiedJson = Map<String, dynamic>.from(json);
            modifiedJson['source_type'] = 'gear';
            return DetectableItem.fromJson(modifiedJson);
          }).where((item) => item.canBeDetected),
        );
      }

      final allItems = [...artifacts, ...gear];

      print(
          '✅🎯 Loaded ${artifacts.length} artifacts, ${gear.length} gear (${allItems.length} total)');

      // ✅ Debug: Print each item's detected type
      for (final item in allItems) {
        print(
            '🔍 Item: ${item.name} | Type: ${item.type} | Source: ${item.sourceType ?? 'unknown'}');
      }

      return {
        'artifacts': artifacts,
        'gear': gear,
        'allItems': allItems,
        'totalCount': allItems.length,
      };
    } catch (e) {
      print('❌🎯 Failed to load zone artifacts: $e');
      rethrow;
    }
  }

  // ✅ Start location tracking
  void startLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      DetectorConfig.LOCATION_UPDATE_INTERVAL,
      (timer) => _updateLocation(),
    );
  }

  // ✅ Stop location tracking
  void stopLocationTracking() {
    _locationTimer?.cancel();
  }

  // ✅ Start detection scanning
  void startDetectionScanning() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(
      DetectorConfig.DETECTION_UPDATE_INTERVAL,
      (timer) => _triggerDetectionUpdate(),
    );
  }

  // ✅ Stop detection scanning
  void stopDetectionScanning() {
    _detectionTimer?.cancel();
  }

  // ✅ Update current location
  Future<void> _updateLocation() async {
    try {
      final location = await LocationService.getCurrentLocation();
      onLocationUpdate?.call(location);
    } catch (e) {
      print('❌ Location update failed: $e');
      onStatusUpdate?.call('Location update failed: $e', isError: true);
    }
  }

  // ✅ Trigger detection update callback
  void _triggerDetectionUpdate() {
    // This will be handled by the provider/notifier
    // Just trigger the callback
    if (onDetectionUpdate != null) {
      // Signal that detection should update
    }
  }

  // ✅ Calculate detection data for items
  Map<String, dynamic> calculateDetectionData(
    List<DetectableItem> items,
    LocationModel? currentLocation,
    Detector detector,
  ) {
    if (currentLocation == null || items.isEmpty) {
      return {
        'updatedItems': <DetectableItem>[],
        'closestItem': null,
        'signalStrength': 0.0,
        'distance': 0.0,
        'direction': 'N/A',
      };
    }

    DetectableItem? closest;
    double minDistance = double.infinity;
    final List<DetectableItem> updatedItems = [];

    // ✅ Calculate distance and bearing for each item
    for (final item in items) {
      final distance = _zoneService.calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        item.latitude,
        item.longitude,
      );

      final bearing = _zoneService.calculateBearing(
        currentLocation.latitude,
        currentLocation.longitude,
        item.latitude,
        item.longitude,
      );

      final compassDirection = _zoneService.bearingToSimpleCompass(bearing);

      // Update item with calculated values
      final updatedItem = item.copyWith(
        distanceFromPlayer: distance,
        bearingFromPlayer: bearing,
        compassDirection: compassDirection,
      );

      updatedItems.add(updatedItem);

      // Track closest item
      if (distance < minDistance) {
        minDistance = distance;
        closest = updatedItem;
      }
    }

    // ✅ Calculate signal strength for closest item
    final signalStrength = closest != null
        ? _zoneService.calculateSignalStrength(
            minDistance,
            maxRangeMeters: detector.maxRangeMeters,
            precisionFactor: detector.precisionFactor,
            itemRarity: closest.rarity,
          )
        : 0.0;

    return {
      'updatedItems': updatedItems,
      'closestItem': closest,
      'signalStrength': signalStrength,
      'distance': minDistance.isFinite ? minDistance : 0.0,
      'direction': closest?.compassDirection ?? 'N/A',
    };
  }

  // ✅ COMPLETELY REWRITTEN: Smart collect item with fallback mechanism
  Future<Map<String, dynamic>> collectItem(
    String zoneId,
    DetectableItem item,
    LocationModel? currentLocation,
  ) async {
    if (currentLocation == null) {
      throw Exception('Current location not available');
    }

    // ✅ Check distance using DetectorConfig
    final currentDistance = _zoneService.calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      item.latitude,
      item.longitude,
    );

    print(
        '🎯 Collection attempt: ${item.name} at distance: ${currentDistance.toStringAsFixed(1)}m');
    print('🎯 Original item type: ${item.type}');
    print('🎯 Source type: ${item.sourceType ?? 'unknown'}');
    print('🎯 Collection radius: ${DetectorConfig.collectionRadius}m');
    print(
        '🎯 Player location: ${currentLocation.latitude}, ${currentLocation.longitude}');
    print('🎯 Item location: ${item.latitude}, ${item.longitude}');

    if (currentDistance > DetectorConfig.collectionRadius) {
      final requiredDistance = DetectorConfig.collectionRadius;
      throw Exception(
          'Move closer to collect this item (within ${requiredDistance}m)\n'
          'Current distance: ${_zoneService.formatDistance(currentDistance)}');
    }

    // ✅ NEW: Smart type detection with fallback
    return await _attemptCollectionWithFallback(zoneId, item);
  }

  // ✅ NEW: Attempt collection with smart fallback mechanism
  Future<Map<String, dynamic>> _attemptCollectionWithFallback(
    String zoneId,
    DetectableItem item,
  ) async {
    // ✅ Strategy 1: Use source type if available (most reliable)
    if (item.sourceType != null) {
      print('🎯💎 Primary attempt: Using source type "${item.sourceType}"');
      try {
        final response =
            await _zoneService.collectItem(zoneId, item.sourceType!, item.id);
        print('✅💎 Collection successful with source type: ${item.sourceType}');
        return response;
      } catch (e) {
        print('❌💎 Source type failed: $e');
      }
    }

    // ✅ Strategy 2: Use enhanced type mapping
    final smartType = _detectItemTypeSmartly(item);
    print('🎯💎 Secondary attempt: Using smart detection "$smartType"');
    try {
      final response =
          await _zoneService.collectItem(zoneId, smartType, item.id);
      print('✅💎 Collection successful with smart type: $smartType');
      return response;
    } catch (e) {
      print('❌💎 Smart type failed: $e');
    }

    // ✅ Strategy 3: Try opposite type as fallback
    final fallbackType = smartType == 'artifact' ? 'gear' : 'artifact';
    print('🎯💎 Fallback attempt: Using opposite type "$fallbackType"');
    try {
      final response =
          await _zoneService.collectItem(zoneId, fallbackType, item.id);
      print('✅💎 Collection successful with fallback type: $fallbackType');
      return response;
    } catch (e) {
      print('❌💎 Fallback type failed: $e');

      // ✅ Final failure - provide detailed error
      throw Exception(
          'Failed to collect "${item.name}" after trying all type strategies:\n'
          '- Source type: ${item.sourceType ?? 'none'}\n'
          '- Smart type: $smartType\n'
          '- Fallback type: $fallbackType\n'
          'Last error: $e');
    }
  }

  // ✅ NEW: Smart type detection using multiple strategies
  String _detectItemTypeSmartly(DetectableItem item) {
    print('🔍 Smart type detection for: ${item.name}');

    // Strategy 1: Check if item has level (gear indicator)
    if (item.level != null && item.level! > 0) {
      print('🔍 → Has level ${item.level}, detected as GEAR');
      return 'gear';
    }

    // Strategy 2: Check if item has rarity but no level (artifact indicator)
    if (item.rarity.isNotEmpty &&
        item.rarity != 'common' &&
        (item.level == null || item.level == 0)) {
      print(
          '🔍 → Has rarity "${item.rarity}" but no level, detected as ARTIFACT');
      return 'artifact';
    }

    // Strategy 3: Name-based detection
    final nameType = _detectTypeFromName(item.name, item.type);
    print('🔍 → Name-based detection: $nameType');

    // Strategy 4: Type-based detection
    final typeBasedType = _mapItemTypeForBackend(item.type);
    print('🔍 → Type-based detection: $typeBasedType');

    // Prefer name-based over type-based if they differ
    final finalType = nameType != 'unknown' ? nameType : typeBasedType;
    print('🔍 → Final decision: $finalType');

    return finalType;
  }

  // ✅ NEW: Enhanced name-based type detection
  String _detectTypeFromName(String name, String type) {
    final lowerName = name.toLowerCase();
    final lowerType = type.toLowerCase();
    final combined = '$lowerName $lowerType';

    // Gear keywords (more specific first)
    final gearKeywords = [
      'helmet',
      'armor',
      'weapon',
      'shield',
      'boots',
      'gloves',
      'sword',
      'axe',
      'bow',
      'staff',
      'mace',
      'dagger',
      'spear',
      'chainmail',
      'platemail',
      'leather',
      'cloth',
      'gauntlets',
      'greaves',
      'bracers',
      'belt'
    ];

    // Artifact keywords
    final artifactKeywords = [
      'orb',
      'crystal',
      'rune',
      'stone',
      'relic',
      'amulet',
      'scroll',
      'potion',
      'gem',
      'jewel',
      'talisman',
      'charm',
      'essence',
      'shard',
      'fragment',
      'core'
    ];

    // Check for gear keywords
    for (final keyword in gearKeywords) {
      if (combined.contains(keyword)) {
        print('🔍 Found gear keyword "$keyword" in "$name"');
        return 'gear';
      }
    }

    // Check for artifact keywords
    for (final keyword in artifactKeywords) {
      if (combined.contains(keyword)) {
        print('🔍 Found artifact keyword "$keyword" in "$name"');
        return 'artifact';
      }
    }

    return 'unknown';
  }

  // ✅ ENHANCED: Map frontend item types to backend expected values
  String _mapItemTypeForBackend(String itemType) {
    final originalType = itemType.toLowerCase();

    final mappedType = switch (originalType) {
      // ✅ Definite artifact types
      'orb' ||
      'rune' ||
      'crystal' ||
      'artifact' ||
      'stone' ||
      'relic' ||
      'treasure' ||
      'amulet' ||
      'scroll' ||
      'potion' ||
      'gem' ||
      'jewel' ||
      'talisman' ||
      'charm' =>
        'artifact',

      // ✅ Definite gear types
      'gear' ||
      'helmet' ||
      'weapon' ||
      'armor' ||
      'tool' ||
      'equipment' ||
      'shield' ||
      'boots' ||
      'gloves' ||
      'sword' ||
      'axe' ||
      'bow' ||
      'staff' =>
        'gear',

      // ✅ Default fallback - prefer artifact for unknown types
      _ => 'artifact',
    };

    if (originalType != mappedType) {
      print('🔄 Type mapping: $originalType → $mappedType');
    }

    return mappedType;
  }

  // ✅ Calculate radar positions for items
  List<Map<String, dynamic>> calculateRadarPositions(
    List<DetectableItem> items,
    Detector detector,
  ) {
    final List<Map<String, dynamic>> radarItems = [];

    for (final item in items.take(DetectorConfig.MAX_RADAR_ITEMS)) {
      final distance = item.distanceFromPlayer ?? 0.0;
      final bearing = item.bearingFromPlayer ?? 0.0;

      // Normalize distance to radar size
      final maxRadius = detector.maxRangeMeters;
      final normalizedDistance = (distance / maxRadius).clamp(0.0, 1.0);
      final radiusFromCenter =
          normalizedDistance * (DetectorConfig.RADAR_DISPLAY_SIZE / 2 - 10);

      // Convert bearing to radar coordinates
      final radians = (bearing - 90) * math.pi / 180; // -90 to make North = up
      final x = radiusFromCenter * math.cos(radians);
      final y = radiusFromCenter * math.sin(radians);

      radarItems.add({
        'item': item,
        'x': x,
        'y': y,
        'distance': distance,
        'bearing': bearing,
        'isVeryClose': item.isVeryClose,
        'isClose': item.isClose,
      });
    }

    return radarItems;
  }

  // ✅ ENHANCED: Format status message with debug info
  String formatStatusMessage(
    bool isLoading,
    bool isScanning,
    bool isCollecting,
    bool hasItems,
    int totalItems,
    bool hasError,
    String? error,
  ) {
    if (isLoading) return 'Loading detector data...';
    if (hasError && error != null) return error;
    if (isCollecting) return 'Collecting item...';

    if (isScanning) {
      if (!hasItems) return 'Scanning for artifacts...';
      final debugInfo = DetectorConfig.isDebugMode
          ? ' (${DetectorConfig.debugModeLabel})'
          : '';
      return 'Scanning... ${totalItems} items detected$debugInfo';
    }

    if (hasItems) {
      final debugInfo = DetectorConfig.isDebugMode
          ? ' (${DetectorConfig.debugModeLabel})'
          : '';
      return 'Detector ready. ${totalItems} items detected$debugInfo';
    }

    return 'No items detected in this zone';
  }

  // ✅ ENHANCED: Get collection debug info
  Map<String, dynamic> getCollectionDebugInfo(
      DetectableItem item, LocationModel location) {
    final distance = _zoneService.calculateDistance(
      location.latitude,
      location.longitude,
      item.latitude,
      item.longitude,
    );

    final smartType = _detectItemTypeSmartly(item);
    final canCollect = distance <= DetectorConfig.collectionRadius;

    return {
      'item_name': item.name,
      'original_type': item.type,
      'source_type': item.sourceType,
      'smart_detected_type': smartType,
      'distance_meters': distance,
      'collection_radius': DetectorConfig.collectionRadius,
      'can_collect': canCollect,
      'distance_formatted': _zoneService.formatDistance(distance),
      'player_location': '${location.latitude}, ${location.longitude}',
      'item_location': '${item.latitude}, ${item.longitude}',
      'debug_mode': DetectorConfig.isDebugMode,
      'debug_label': DetectorConfig.debugModeLabel,
      'has_level': item.level != null && item.level! > 0,
      'rarity': item.rarity,
    };
  }

  // ✅ ENHANCED: Validate collection requirements
  String? validateCollection(DetectableItem item, LocationModel? location) {
    if (location == null) {
      return 'Location not available';
    }

    final distance = _zoneService.calculateDistance(
      location.latitude,
      location.longitude,
      item.latitude,
      item.longitude,
    );

    if (distance > DetectorConfig.collectionRadius) {
      return 'Too far away (${distance.toStringAsFixed(1)}m > ${DetectorConfig.collectionRadius}m)';
    }

    return null; // No validation errors
  }

  // ✅ Dispose resources
  void dispose() {
    _locationTimer?.cancel();
    _detectionTimer?.cancel();
  }
}
