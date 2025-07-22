// lib/features/detector/models/detection_state.dart
import 'package:equatable/equatable.dart';
import '../../map/models/location_model.dart';
import 'artifact_model.dart';

class DetectionState extends Equatable {
  final bool isLoading;
  final bool isScanning;
  final bool isCollecting;
  final LocationModel? currentLocation;
  final List<DetectableItem> allItems;
  final List<DetectableItem> detectableItems;
  final DetectableItem? closestItem;
  final double signalStrength;
  final String direction;
  final double distance;
  final String status;
  final String? error;

  // ✅ Additional state for UI
  final int artifactCount;
  final int gearCount;
  final bool hasLocationPermission;

  const DetectionState({
    this.isLoading = false,
    this.isScanning = false,
    this.isCollecting = false,
    this.currentLocation,
    this.allItems = const [],
    this.detectableItems = const [],
    this.closestItem,
    this.signalStrength = 0.0,
    this.direction = 'N/A',
    this.distance = 0.0,
    this.status = 'Initializing detector...',
    this.error,
    this.artifactCount = 0,
    this.gearCount = 0,
    this.hasLocationPermission = false,
  });

  // ✅ Helper getters
  bool get hasError => error != null;
  bool get hasItems => allItems.isNotEmpty;
  bool get canScan => !isLoading && !isCollecting && hasLocationPermission;
  bool get hasSignal => signalStrength > 0.0;
  int get totalItems => allItems.length;

  // ✅ Signal strength helpers
  String get signalStrengthText {
    if (signalStrength >= 0.8) return 'Very Strong';
    if (signalStrength >= 0.6) return 'Strong';
    if (signalStrength >= 0.4) return 'Medium';
    if (signalStrength >= 0.2) return 'Weak';
    if (signalStrength > 0) return 'Very Weak';
    return 'No Signal';
  }

  String get statusMessage {
    if (isLoading) return 'Loading detector data...';
    if (!hasLocationPermission) return 'Location permission required';
    if (hasError) return error!;
    if (isCollecting) return 'Collecting item...';
    if (isScanning && !hasItems) return 'Scanning for artifacts...';
    if (isScanning && hasSignal) return 'Artifact detected!';
    if (isScanning) return 'Scanning... ${totalItems} items found';
    if (hasItems) return 'Ready to scan. ${totalItems} items detected';
    return 'No items detected in this zone';
  }

  DetectionState copyWith({
    bool? isLoading,
    bool? isScanning,
    bool? isCollecting,
    LocationModel? currentLocation,
    List<DetectableItem>? allItems,
    List<DetectableItem>? detectableItems,
    DetectableItem? closestItem,
    double? signalStrength,
    String? direction,
    double? distance,
    String? status,
    String? error,
    int? artifactCount,
    int? gearCount,
    bool? hasLocationPermission,
  }) {
    return DetectionState(
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      isCollecting: isCollecting ?? this.isCollecting,
      currentLocation: currentLocation ?? this.currentLocation,
      allItems: allItems ?? this.allItems,
      detectableItems: detectableItems ?? this.detectableItems,
      closestItem: closestItem ?? this.closestItem,
      signalStrength: signalStrength ?? this.signalStrength,
      direction: direction ?? this.direction,
      distance: distance ?? this.distance,
      status: status ?? this.status,
      error: error, // Allow nullifying error
      artifactCount: artifactCount ?? this.artifactCount,
      gearCount: gearCount ?? this.gearCount,
      hasLocationPermission:
          hasLocationPermission ?? this.hasLocationPermission,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isScanning,
        isCollecting,
        currentLocation,
        allItems,
        detectableItems,
        closestItem,
        signalStrength,
        direction,
        distance,
        status,
        error,
        artifactCount,
        gearCount,
        hasLocationPermission,
      ];

  @override
  String toString() =>
      'DetectionState(scanning: $isScanning, items: ${allItems.length}, signal: $signalStrength)';
}
