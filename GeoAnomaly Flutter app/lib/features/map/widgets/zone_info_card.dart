import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/zone_model.dart';
import '../models/scan_result_model.dart' as scan; // ✅ FIX: Pridaj import

class ZoneInfoCard extends StatelessWidget {
  final Zone zone;
  final scan.ZoneWithDetails? zoneDetails; // ✅ FIX: Pridaj optional zoneDetails
  final VoidCallback onEnterZone;
  final VoidCallback onNavigateToZone;

  const ZoneInfoCard({
    super.key,
    required this.zone,
    this.zoneDetails, // ✅ FIX: Pridaj parameter
    required this.onEnterZone,
    required this.onNavigateToZone,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Zone header
                  Row(
                    children: [
                      Text(
                        zone.biomeEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          zone.name,
                          style: GameTextStyles.clockTime.copyWith(
                            fontSize: 22,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      Text(
                        zone.dangerLevelEmoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Zone description
                  if (zone.description != null && zone.description!.isNotEmpty)
                    Text(
                      zone.description!,
                      style: GameTextStyles.clockLabel.copyWith(
                        fontSize: 14,
                        color: Colors.grey[300],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Zone info grid
                  _buildInfoGrid(),

                  const SizedBox(height: 20),

                  // ✅ FIX: Enhanced zone details with ZoneWithDetails
                  if (zoneDetails != null) _buildZoneDetails(),

                  const SizedBox(height: 20),

                  // TTL info if expires
                  _buildTTLInfo(),

                  const SizedBox(height: 20),

                  // Action buttons
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child:
                    _buildInfoItem('Tier Required', zone.tierName, Icons.star),
              ),
              Expanded(
                child: _buildInfoItem(
                    'Biome', zone.biome ?? 'Unknown', Icons.terrain),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                    'Danger', zone.dangerLevel ?? 'Unknown', Icons.warning),
              ),
              Expanded(
                child: _buildInfoItem(
                    'Radius', '${zone.radiusMeters}m', Icons.circle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ FIX: New method for ZoneWithDetails info
  Widget _buildZoneDetails() {
    if (zoneDetails == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zone Status',
            style: GameTextStyles.clockTime.copyWith(
              fontSize: 16,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  'Distance',
                  zoneDetails!.distanceText,
                  Icons.near_me,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Status',
                  zoneDetails!.statusText,
                  Icons.info,
                  _getStatusColor(zoneDetails!.statusText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  'Artifacts',
                  '${zoneDetails!.activeArtifacts}',
                  Icons.diamond,
                  Colors.purple,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Gear',
                  '${zoneDetails!.activeGear}',
                  Icons.construction,
                  Colors.orange,
                ),
              ),
            ],
          ),
          if (zoneDetails!.activePlayers > 0) ...[
            const SizedBox(height: 12),
            _buildStatusItem(
              'Players',
              '${zoneDetails!.activePlayers} active',
              Icons.people,
              Colors.green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusItem(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GameTextStyles.clockLabel.copyWith(fontSize: 11),
            ),
            Text(
              value,
              style: GameTextStyles.clockTime.copyWith(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'empty':
        return Colors.grey;
      case 'expired':
        return Colors.red;
      default:
        if (status.contains('players')) return Colors.blue;
        return Colors.white;
    }
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GameTextStyles.clockLabel.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GameTextStyles.clockTime.copyWith(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTTLInfo() {
    // ✅ FIX: Use ZoneWithDetails expiry if available, otherwise zone expiry
    DateTime? expiresAt =
        zone.expiresAt != null ? DateTime.tryParse(zone.expiresAt!) : null;
    if (zoneDetails != null && !zoneDetails!.isExpired) {
      expiresAt = zoneDetails!.expiryDateTime;
    }

    if (expiresAt == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final timeLeft = expiresAt.difference(now);
    final isExpiring = timeLeft.inHours < 1;
    final isExpired = timeLeft.isNegative;

    if (isExpired) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Zone has expired',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExpiring
            ? Colors.red.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExpiring ? Colors.red : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: isExpiring ? Colors.red : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isExpiring
                ? 'Expires in ${timeLeft.inMinutes}m ${timeLeft.inSeconds % 60}s'
                : 'Expires in ${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m',
            style: TextStyle(
              color: isExpiring ? Colors.red : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final isExpired = zoneDetails?.isExpired ?? false;
    final canEnter = zoneDetails?.canEnter ?? true;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onNavigateToZone,
            icon: const Icon(Icons.info_outline),
            label: const Text('View Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cardColor,
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (isExpired || !canEnter) ? null : onEnterZone,
            icon: Icon(isExpired ? Icons.block : Icons.login),
            label: Text(isExpired ? 'Expired' : 'Enter Zone'),
            style: ElevatedButton.styleFrom(
              backgroundColor: (isExpired || !canEnter)
                  ? Colors.grey
                  : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
