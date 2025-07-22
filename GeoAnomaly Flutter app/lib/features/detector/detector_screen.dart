import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

import 'models/detector_model.dart';
import 'models/artifact_model.dart';
import 'models/detector_config.dart';
import 'models/detection_state.dart';
import 'providers/detection_provider.dart';

// ✅ FIXED: Uncomment animated widgets
import 'widgets/detector_header.dart';
import 'widgets/signal_strength_widget.dart';
import 'widgets/detection_controls.dart';
import 'widgets/target_info_widget.dart';
import 'widgets/radar_display.dart';

class DetectorScreen extends ConsumerStatefulWidget {
  final String zoneId;
  final Detector detector;

  const DetectorScreen({
    super.key,
    required this.zoneId,
    required this.detector,
  });

  @override
  ConsumerState<DetectorScreen> createState() => _DetectorScreenState();
}

class _DetectorScreenState extends ConsumerState<DetectorScreen> {
  late DetectionProviderParams _params;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _params = DetectionProviderParams(
      zoneId: widget.zoneId,
      detector: widget.detector,
    );
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detectionProvider(_params));
    final isLoading = state.isLoading;

    // Listen for collection success state changes
    ref.listen(detectionProvider(_params), (previous, next) {
      _handleCollectionStateChange(previous, next);
    });

    // Loading screen
    if (isLoading && state.allItems.isEmpty) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // ✅ FIXED: Use animated header instead of simple
          DetectorHeader(
            detector: widget.detector,
            zoneId: widget.zoneId,
            onExitPressed: _handleExit,
          ),

          // Main content
          Expanded(
            child: _buildMainContent(),
          ),

          // ✅ FIXED: Use animated controls instead of simple
          DetectionControls(
            zoneId: widget.zoneId,
            detector: widget.detector,
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Main content with animated widgets
  Widget _buildMainContent() {
    final state = ref.watch(detectionProvider(_params));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Error display
          if (state.hasError) _buildErrorCard(),

          // Collection status overlay
          if (state.isCollecting) _buildCollectionOverlay(),

          // ✅ FIXED: Animated radar and signal widgets
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated radar display
              Expanded(
                flex: 3,
                child: RadarDisplay(
                  zoneId: widget.zoneId,
                  detector: widget.detector,
                ),
              ),

              const SizedBox(width: 16),

              // Animated signal strength
              Expanded(
                flex: 2,
                child: SignalStrengthWidget(
                  zoneId: widget.zoneId,
                  detector: widget.detector,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ FIXED: Animated target info instead of simple
          TargetInfoWidget(
            zoneId: widget.zoneId,
            detector: widget.detector,
            onCollectPressed: () {
              // Optional callback for additional feedback
            },
          ),

          const SizedBox(height: 16),

          // Items list
          if (state.hasItems) _buildSimpleItemsList(),

          // Debug panel
          if (DetectorConfig.isDebugMode) ...[
            const SizedBox(height: 16),
            _buildDebugPanel(),
          ],

          // Empty state message
          if (!state.hasItems && !state.isLoading) _buildEmptyState(),
        ],
      ),
    );
  }

  // Keep existing methods...
  void _handleCollectionStateChange(
      DetectionState? previous, DetectionState? next) {
    if (previous == null || next == null) return;

    if (previous.isCollecting &&
        !next.isCollecting &&
        next.error == null &&
        next.status.contains('Collected')) {
      final statusMatch = RegExp(r'Collected (.+?)!').firstMatch(next.status);
      if (statusMatch != null) {
        final itemName = statusMatch.group(1)!;
        _showCollectionSuccess(itemName);
      }
    } else if (previous.isCollecting &&
        !next.isCollecting &&
        next.error != null) {
      _showCollectionError(next.error!);
    }
  }

  void _showCollectionSuccess(String itemName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Successfully collected $itemName!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'VIEW INVENTORY',
          textColor: Colors.white,
          onPressed: () => context.push('/inventory'),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showCollectionError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Collection failed: ${error.length > 100 ? error.substring(0, 100) + '...' : error}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: () {
            ref.read(detectionProvider(_params).notifier).clearError();
          },
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Keep all other existing methods (_buildSimpleItemsList, _buildCollectionOverlay, etc.)...

  Widget _buildSimpleItemsList() {
    final state = ref.watch(detectionProvider(_params));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.list, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Detected Items (${state.detectableItems.length})',
                  style: GameTextStyles.cardTitle.copyWith(fontSize: 16),
                ),
                const Spacer(),
                Text(
                  'Max: ${DetectorConfig.MAX_RADAR_ITEMS}',
                  style: GameTextStyles.cardSubtitle.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.detectableItems
                .take(DetectorConfig.MAX_RADAR_ITEMS)
                .length,
            separatorBuilder: (_, __) =>
                Divider(color: AppTheme.borderColor, height: 1),
            itemBuilder: (context, index) {
              final item = state.detectableItems[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getRarityColor(item.rarity).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getItemIcon(item.type),
                    color: _getRarityColor(item.rarity),
                    size: 20,
                  ),
                ),
                title: Text(
                  item.name,
                  style: GameTextStyles.cardTitle.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${item.rarityDisplayName} • ${item.distanceDisplay} ${item.compassDirectionDisplay}',
                  style: GameTextStyles.cardSubtitle.copyWith(fontSize: 12),
                ),
                trailing: item.isVeryClose
                    ? ElevatedButton(
                        onPressed: state.isCollecting
                            ? null
                            : () => _collectItemWithConfirmation(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(60, 30),
                        ),
                        child: state.isCollecting
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Collect',
                                style: TextStyle(fontSize: 10)),
                      )
                    : Text(
                        item.distanceDisplay,
                        style:
                            GameTextStyles.cardSubtitle.copyWith(fontSize: 10),
                      ),
                onTap: () => _showItemDetails(item),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionOverlay() {
    final state = ref.watch(detectionProvider(_params));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collection in Progress',
                  style: GameTextStyles.cardTitle.copyWith(
                    color: AppTheme.primaryColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.status,
                  style: GameTextStyles.cardSubtitle.copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _collectItemWithConfirmation(DetectableItem item) {
    if (!item.isVeryClose) {
      _showDistanceWarning(item);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text('Collect Item?', style: GameTextStyles.cardTitle),
        content: Text(
          'Collect "${item.name}"?\n\nThis action cannot be undone.',
          style: GameTextStyles.cardSubtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performCollection(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Collect'),
          ),
        ],
      ),
    );
  }

  void _showDistanceWarning(DetectableItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Text('Too Far Away', style: GameTextStyles.cardTitle),
          ],
        ),
        content: Text(
          'You need to be within ${DetectorConfig.collectionRadius}m of "${item.name}" to collect it.\n\n'
          'Current distance: ${item.distanceDisplay}',
          style: GameTextStyles.cardSubtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _performCollection(DetectableItem item) {
    print('🎯 User initiated collection for: ${item.name}');
    ref.read(detectionProvider(_params).notifier).collectItem(item);
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          '🎯 ${widget.detector.name}',
          style: GameTextStyles.clockTime.copyWith(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 24),
            Text(
              'Initializing Detector',
              style: GameTextStyles.clockTime.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading zone artifacts...',
              style: GameTextStyles.cardSubtitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Text(
                widget.detector.name,
                style: GameTextStyles.cardTitle.copyWith(fontSize: 14),
              ),
            ),
            if (DetectorConfig.isDebugMode) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bug_report,
                            color: Colors.orange[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'DEBUG MODE ACTIVE',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Collection radius: ${DetectorConfig.collectionRadius}m',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    final state = ref.watch(detectionProvider(_params));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detection Error',
                  style: GameTextStyles.cardTitle.copyWith(
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.error ?? 'Unknown error occurred',
                  style: GameTextStyles.cardSubtitle.copyWith(
                    color: Colors.red[300],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                ref.read(detectionProvider(_params).notifier).clearError(),
            icon: const Icon(Icons.close, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final state = ref.watch(detectionProvider(_params));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No Items Detected',
            style: GameTextStyles.clockTime.copyWith(
              fontSize: 18,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.hasLocationPermission
                ? 'This zone appears to be empty.\nTry scanning or move to a different area.'
                : 'Location permission is required to detect items.',
            style: GameTextStyles.cardSubtitle.copyWith(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (!state.hasLocationPermission)
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(detectionProvider(_params).notifier).refresh(),
              icon: const Icon(Icons.location_on),
              label: const Text('Enable Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(detectionProvider(_params).notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Zone'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDebugPanel() {
    final state = ref.watch(detectionProvider(_params));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'DEBUG PANEL',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDebugRow('Zone ID', widget.zoneId),
          _buildDebugRow('Detector', widget.detector.name),
          _buildDebugRow(
              'Collection Radius', '${DetectorConfig.collectionRadius}m'),
          _buildDebugRow('Max Range', '${widget.detector.maxRangeMeters}m'),
          _buildDebugRow('Total Items', '${state.allItems.length}'),
          _buildDebugRow('Detectable Items', '${state.detectableItems.length}'),
          _buildDebugRow('Artifacts', '${state.artifactCount}'),
          _buildDebugRow('Gear', '${state.gearCount}'),
          _buildDebugRow('Scanning', state.isScanning ? 'YES' : 'NO'),
          _buildDebugRow('Collecting', state.isCollecting ? 'YES' : 'NO'),
          _buildDebugRow(
              'Signal Strength', '${(state.signalStrength * 100).toInt()}%'),
          if (state.closestItem != null) ...[
            _buildDebugRow('Closest Item', state.closestItem!.name),
            _buildDebugRow('Distance', '${state.distance.toStringAsFixed(1)}m'),
            _buildDebugRow('Direction', state.direction),
          ],
          if (state.currentLocation != null) ...[
            _buildDebugRow('Latitude',
                '${state.currentLocation!.latitude.toStringAsFixed(6)}'),
            _buildDebugRow('Longitude',
                '${state.currentLocation!.longitude.toStringAsFixed(6)}'),
          ],
        ],
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showItemDetails(DetectableItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Row(
          children: [
            Icon(
              _getItemIcon(item.type),
              color: _getRarityColor(item.rarity),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.name,
                style: GameTextStyles.cardTitle,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.description.isNotEmpty) ...[
                Text(
                  item.description,
                  style: GameTextStyles.cardSubtitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 16),
              ],
              _buildDetailRow('Type', item.type.toUpperCase()),
              _buildDetailRow('Rarity', item.rarityDisplayName),
              _buildDetailRow('Material', item.materialDisplayName),
              if (item.value > 0)
                _buildDetailRow('Value', '${item.value} credits'),
              if (item.distanceFromPlayer != null)
                _buildDetailRow('Distance', item.distanceDisplay),
              if (item.compassDirectionDisplay.isNotEmpty)
                _buildDetailRow('Direction', item.compassDirectionDisplay),
              if (DetectorConfig.isDebugMode) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
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
                        'ID: ${item.id}\n'
                        'Source: ${item.sourceType ?? 'unknown'}\n'
                        'Level: ${item.level ?? 'none'}\n'
                        'Lat: ${item.latitude}\n'
                        'Lng: ${item.longitude}\n'
                        'Can Detect: ${item.canBeDetected}\n'
                        'Difficulty: ${item.detectionDifficulty}',
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (item.isVeryClose)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _collectItemWithConfirmation(item);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Collect'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GameTextStyles.cardSubtitle.copyWith(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GameTextStyles.cardTitle.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _handleExit() {
    ref.invalidate(detectionProvider(_params));
    context.pop();
  }

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
        return Colors.grey;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  IconData _getItemIcon(String type) {
    switch (type.toLowerCase()) {
      case 'artifact':
        return Icons.diamond;
      case 'gear':
        return Icons.build;
      default:
        return Icons.help_outline;
    }
  }
}
