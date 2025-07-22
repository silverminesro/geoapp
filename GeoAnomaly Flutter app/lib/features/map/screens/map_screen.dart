import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../services/location_service.dart';
import '../services/zone_service.dart';
import '../models/location_model.dart';
import '../../../core/models/zone_model.dart';
import '../models/scan_result_model.dart' as ScanModels;
import '../widgets/zone_info_card.dart';
import '../widgets/scan_button.dart';

class MapScreen extends StatefulWidget {
  final Map<String, dynamic>? extras;

  const MapScreen({super.key, this.extras});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LocationModel? _currentLocation;
  List<Marker> _markers = [];
  List<ScanModels.ZoneWithDetails> _zones = [];
  ScanModels.ScanResultModel? _lastScanResult;
  bool _isLoading = false;
  bool _isScanning = false;

  final ZoneService _zoneService = ZoneService();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _handleExtras();
  }

  void _handleExtras() {
    if (widget.extras != null) {
      final extras = widget.extras!;

      // Handle discovery location navigation
      if (extras.containsKey('center_location')) {
        final location = extras['center_location'] as Location;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(
            LatLng(location.latitude, location.longitude),
            17.0, // Closer zoom for discovery location
          );

          // Show discovery marker if requested
          if (extras['show_discovery_marker'] == true) {
            _addDiscoveryMarker(location, extras['discovery_item_name']);
          }
        });
      }
    }
  }

  void _addDiscoveryMarker(Location location, String? itemName) {
    final discoveryMarker = Marker(
      point: LatLng(location.latitude, location.longitude),
      width: 60,
      height: 60,
      child: GestureDetector(
        onTap: () => _showDiscoveryInfo(location, itemName),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.purple,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_history,
                color: Colors.white,
                size: 20,
              ),
              Text(
                'FOUND',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    setState(() {
      _markers = [..._markers, discoveryMarker];
    });
  }

  void _showDiscoveryInfo(Location location, String? itemName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Row(
          children: [
            Icon(Icons.location_history, color: Colors.purple),
            const SizedBox(width: 8),
            Text(
              'Discovery Location',
              style: GameTextStyles.clockTime.copyWith(fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (itemName != null) ...[
              Text(
                'Item: $itemName',
                style: GameTextStyles.cardTitle,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Coordinates:',
              style: GameTextStyles.clockLabel,
            ),
            Text(
              '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
              style: GameTextStyles.cardTitle.copyWith(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/inventory');
            },
            child: const Text('View Inventory'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final location = await LocationService.getCurrentLocation();
      setState(() {
        _currentLocation = location;
        _isLoading = false;
      });

      // Move camera to current location only if no extras location is provided
      if (widget.extras?['center_location'] == null) {
        _mapController.move(
          LatLng(location.latitude, location.longitude),
          15.0,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error getting location: $e');
    }
  }

  Future<void> _scanArea() async {
    if (_currentLocation == null) {
      _showErrorSnackBar('Location not available');
      return;
    }

    // Check cooldown
    if (_lastScanResult != null && !_lastScanResult!.canScanAgain) {
      final remaining = _lastScanResult!.cooldownRemaining;
      _showErrorSnackBar(
          'Scan cooldown: ${remaining.inMinutes}m ${remaining.inSeconds % 60}s remaining');
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final scanResult = await _zoneService.scanArea(_currentLocation!);

      setState(() {
        _lastScanResult = scanResult;
        _zones = scanResult.zones;
        _markers = _createZoneMarkers(scanResult.zones);
        _isScanning = false;
      });

      _showSuccessSnackBar(
          'Found ${scanResult.zones.length} zones! (${scanResult.zonesCreated} new)');
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _showErrorSnackBar('Error scanning area: $e');
    }
  }

  List<Marker> _createZoneMarkers(List<ScanModels.ZoneWithDetails> zones) {
    List<Marker> markers = [];

    // Add zone markers
    for (final zoneWithDetails in zones) {
      final zone = zoneWithDetails.zone;
      markers.add(
        Marker(
          point: LatLng(zone.location.latitude, zone.location.longitude),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _showZoneDetails(zoneWithDetails),
            child: Container(
              decoration: BoxDecoration(
                color: _getMarkerColor(zone.tierRequired),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      zone.biomeEmoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      'T${zone.tierRequired}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Color _getMarkerColor(int tier) {
    switch (tier) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.yellow;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  void _showZoneDetails(ScanModels.ZoneWithDetails zoneWithDetails) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ZoneInfoCard(
        zone: zoneWithDetails.zone,
        zoneDetails: zoneWithDetails,
        onEnterZone: () => _enterZone(zoneWithDetails.zone),
        onNavigateToZone: () => _navigateToZone(zoneWithDetails.zone),
      ),
    );
  }

  Future<void> _enterZone(Zone zone) async {
    try {
      Navigator.pop(context);
      setState(() {
        _isLoading = true;
      });

      await _zoneService.enterZone(zone.id);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showSuccessSnackBar('Successfully entered ${zone.name}!');
        context.push('/zone/${zone.id}', extra: zone);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error entering zone: $e');
    }
  }

  void _navigateToZone(Zone zone) {
    Navigator.pop(context);
    print('🗺️ Navigating to zone: ${zone.name}');
    context.push('/zone/${zone.id}', extra: zone);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'GeoAnomaly',
          style: GameTextStyles.clockTime.copyWith(
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () => context.go('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2, color: Colors.white),
            onPressed: () => context.go('/inventory'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 🗺️ Flutter Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation != null
                  ? LatLng(
                      _currentLocation!.latitude, _currentLocation!.longitude)
                  : const LatLng(48.1486, 17.1077),
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.geoanomaly.app',
                maxNativeZoom: 18,
              ),
              MarkerLayer(markers: _markers),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_currentLocation!.latitude,
                          _currentLocation!.longitude),
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            ),

          // Scan button
          Positioned(
            bottom: 100,
            right: 20,
            child: ScanButton(
              onPressed: _isScanning ? null : _scanArea,
              isScanning: _isScanning,
              cooldownRemaining: _lastScanResult?.cooldownRemaining,
            ),
          ),

          // Location button
          Positioned(
            bottom: 180,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              heroTag: "location_button",
              onPressed: () async {
                try {
                  final location = await LocationService.getCurrentLocation();
                  setState(() {
                    _currentLocation = location;
                  });
                  _mapController.move(
                      LatLng(location.latitude, location.longitude), 15.0);
                } catch (e) {
                  _showErrorSnackBar('Error getting location: $e');
                }
              },
              child: Icon(Icons.my_location, color: AppTheme.primaryColor),
            ),
          ),

          // Zone count info
          if (_zones.isNotEmpty)
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_zones.length} zones found',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
