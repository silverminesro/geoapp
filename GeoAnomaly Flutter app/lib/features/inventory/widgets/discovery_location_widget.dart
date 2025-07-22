import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/zone_model.dart';

class DiscoveryLocationWidget extends StatelessWidget {
  final Location location;
  final DateTime? timestamp;
  final String? itemName;
  final bool showTimestamp;
  final double height;

  const DiscoveryLocationWidget({
    super.key,
    required this.location,
    this.timestamp,
    this.itemName,
    this.showTimestamp = true,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Map
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(location.latitude, location.longitude),
                initialZoom: 16.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.geoanomaly.app',
                  maxNativeZoom: 18,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Info overlay
            if (showTimestamp && timestamp != null)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (itemName != null) ...[
                        Text(
                          itemName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                      ],
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatTimestamp(timestamp!),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.place,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Zoom controls
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        IconButton(
                          onPressed: () {
                            // Would need map controller to implement zoom
                            // For now, this is a placeholder
                          },
                          icon: const Icon(Icons.add, size: 16),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        Container(
                          height: 1,
                          color: Colors.grey[300],
                        ),
                        IconButton(
                          onPressed: () {
                            // Would need map controller to implement zoom
                            // For now, this is a placeholder
                          },
                          icon: const Icon(Icons.remove, size: 16),
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return 'Found ${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return 'Found ${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return 'Found ${difference.inMinutes} minutes ago';
    } else {
      return 'Just discovered';
    }
  }
}

// Simplified version without map (for cases where map is not needed)
class DiscoveryLocationInfo extends StatelessWidget {
  final Location location;
  final DateTime? timestamp;
  final String? itemName;

  const DiscoveryLocationInfo({
    super.key,
    required this.location,
    this.timestamp,
    this.itemName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (itemName != null) ...[
            Text(
              'Discovery Location',
              style: GameTextStyles.clockTime.copyWith(
                fontSize: 14,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              const Icon(
                Icons.place,
                color: Colors.red,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                  style: GameTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTimestamp(timestamp!),
                  style: GameTextStyles.clockLabel.copyWith(fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return 'Found ${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return 'Found ${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return 'Found ${difference.inMinutes} minutes ago';
    } else {
      return 'Just discovered';
    }
  }
}
