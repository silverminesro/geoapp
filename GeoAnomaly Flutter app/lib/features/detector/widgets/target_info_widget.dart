// lib/features/detector/widgets/target_info_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/artifact_model.dart';
import '../models/detector_model.dart';
import '../models/detector_config.dart';
import '../providers/detection_provider.dart';
import '../models/detection_state.dart';

class TargetInfoWidget extends ConsumerWidget {
  final String zoneId;
  final Detector detector;
  final VoidCallback? onCollectPressed;

  const TargetInfoWidget({
    super.key,
    required this.zoneId,
    required this.detector,
    this.onCollectPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = DetectionProviderParams(zoneId: zoneId, detector: detector);
    final closestItem = ref.watch(closestItemProvider(params));
    final state = ref.watch(detectionProvider(params));
    final notifier = ref.read(detectionProvider(params).notifier);

    if (closestItem == null) {
      return _buildEmptyState(state);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Header with target info
          Row(
            children: [
              Text(
                'Target Detected',
                style: GameTextStyles.cardTitle.copyWith(
                  fontSize: 14,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              if (closestItem.isVeryClose)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'COLLECT READY',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (closestItem.isClose)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'CLOSE',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ✅ Item info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getRarityColor(closestItem.rarity).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getRarityColor(closestItem.rarity).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name and type
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        closestItem.name,
                        style: GameTextStyles.cardTitle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      closestItem.type.toUpperCase(),
                      style: GameTextStyles.cardSubtitle.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Item properties
                Row(
                  children: [
                    Expanded(
                      child: _buildItemProperty(
                        'Rarity',
                        closestItem.rarityDisplayName,
                        _getRarityColor(closestItem.rarity),
                      ),
                    ),
                    Expanded(
                      child: _buildItemProperty(
                        'Material',
                        closestItem.materialDisplayName,
                        AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Distance and direction
                Row(
                  children: [
                    Expanded(
                      child: _buildItemProperty(
                        'Distance',
                        closestItem.distanceDisplay,
                        closestItem.isVeryClose
                            ? Colors.green
                            : closestItem.isClose
                                ? Colors.orange
                                : AppTheme.textSecondaryColor,
                      ),
                    ),
                    Expanded(
                      child: _buildItemProperty(
                        'Direction',
                        closestItem.compassDirectionDisplay,
                        AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),

                if (closestItem.value > 0) ...[
                  const SizedBox(height: 8),
                  _buildItemProperty(
                    'Value',
                    '${closestItem.value} credits',
                    Colors.amber,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ✅ Action buttons
          Row(
            children: [
              // Collect button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _canCollect(closestItem, state)
                      ? () => _handleCollect(notifier, closestItem)
                      : null,
                  icon: state.isCollecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_getCollectIcon(closestItem)),
                  label: Text(_getCollectButtonText(closestItem, state)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: closestItem.isVeryClose
                        ? Colors.green
                        : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Info button
              IconButton(
                onPressed: () => _showItemDetails(context, closestItem),
                icon: const Icon(Icons.info_outline),
                color: AppTheme.textSecondaryColor,
                tooltip: 'Item Details',
              ),
            ],
          ),

          // ✅ Debug information
          if (DetectorConfig.isDebugMode) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEBUG INFO:',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    closestItem.debugProximityInfo,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[700],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ Empty state when no target
  Widget _buildEmptyState(DetectionState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Icon(
            state.isScanning ? Icons.search : Icons.radar,
            size: 32,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 8),
          Text(
            state.isScanning
                ? 'Searching for targets...'
                : 'No targets detected',
            style: GameTextStyles.cardSubtitle.copyWith(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (!state.isScanning && state.hasItems) ...[
            const SizedBox(height: 4),
            Text(
              'Start scanning to detect nearby items',
              style: GameTextStyles.cardSubtitle.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ✅ Build item property display
  Widget _buildItemProperty(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GameTextStyles.cardSubtitle.copyWith(fontSize: 11),
        ),
        Text(
          value,
          style: GameTextStyles.cardTitle.copyWith(
            fontSize: 12,
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ✅ Check if item can be collected
  bool _canCollect(DetectableItem item, DetectionState state) {
    return !state.isCollecting &&
        !state.isLoading &&
        item.isVeryClose &&
        item.canBeDetected;
  }

  // ✅ Handle collect button press
  void _handleCollect(DetectionNotifier notifier, DetectableItem item) {
    notifier.collectItem(item);
    onCollectPressed?.call();
  }

  // ✅ Get collect button icon
  IconData _getCollectIcon(DetectableItem item) {
    if (item.isVeryClose) return Icons.download;
    return Icons.near_me;
  }

  // ✅ Get collect button text
  String _getCollectButtonText(DetectableItem item, DetectionState state) {
    if (state.isCollecting) return 'Collecting...';
    if (item.isVeryClose) return 'Collect';
    return 'Move Closer';
  }

  // ✅ Get rarity color
  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return Colors.purple;
      case 'epic':
        return Colors.deepPurple;
      case 'rare':
        return Colors.blue;
      case 'uncommon':
        return Colors.green;
      case 'common':
      default:
        return Colors.grey;
    }
  }

  // ✅ Show item details dialog
  void _showItemDetails(BuildContext context, DetectableItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(
          item.name,
          style: GameTextStyles.cardTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.description.isNotEmpty) ...[
              Text(
                item.description,
                style: GameTextStyles.cardSubtitle,
              ),
              const SizedBox(height: 12),
            ],
            Text('Type: ${item.type}'),
            Text('Rarity: ${item.rarityDisplayName}'),
            Text('Material: ${item.materialDisplayName}'),
            if (item.value > 0) Text('Value: ${item.value} credits'),
            Text('Distance: ${item.distanceDisplay}'),
            Text('Direction: ${item.compassDirectionDisplay}'),
            if (DetectorConfig.isDebugMode) ...[
              const SizedBox(height: 8),
              Text(
                'DEBUG:\nLat: ${item.latitude}\nLng: ${item.longitude}\nID: ${item.id}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
