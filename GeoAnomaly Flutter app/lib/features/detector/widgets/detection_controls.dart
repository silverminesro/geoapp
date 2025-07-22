// lib/features/detector/widgets/detection_controls.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/detector_model.dart';
import '../models/detection_state.dart';
import '../providers/detection_provider.dart';

class DetectionControls extends ConsumerWidget {
  final String zoneId;
  final Detector detector;

  const DetectionControls({
    super.key,
    required this.zoneId,
    required this.detector,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = DetectionProviderParams(zoneId: zoneId, detector: detector);
    final state = ref.watch(detectionProvider(params));
    final notifier = ref.read(detectionProvider(params).notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ Main action button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: state.canScan ? () => _handleMainAction(ref) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    state.isScanning ? Colors.red : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: state.isScanning ? 0 : 2,
              ),
              child: _buildMainButtonContent(state),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ Secondary actions row
          Row(
            children: [
              // Refresh button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.isLoading ? null : () => notifier.refresh(),
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Clear error button (only when error exists)
              if (state.hasError)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => notifier.clearError(),
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ✅ Item count info
          if (state.hasItems) ...[
            const SizedBox(height: 8),
            Text(
              '${state.totalItems} items detected • '
              '${state.detectableItems.length} in range • '
              'A:${state.artifactCount} G:${state.gearCount}',
              style: GameTextStyles.cardSubtitle.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ✅ Handle main action button press
  void _handleMainAction(WidgetRef ref) {
    final params = DetectionProviderParams(zoneId: zoneId, detector: detector);
    final notifier = ref.read(detectionProvider(params).notifier);
    final state = ref.read(detectionProvider(params));

    if (state.isScanning) {
      notifier.stopScanning();
    } else {
      notifier.startScanning();
    }
  }

  // ✅ Build main button content
  Widget _buildMainButtonContent(DetectionState state) {
    if (state.isLoading) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 12),
          Text('Loading...'),
        ],
      );
    }

    if (!state.hasLocationPermission) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off),
          SizedBox(width: 8),
          Text('Location Required'),
        ],
      );
    }

    if (state.isScanning) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.stop),
          SizedBox(width: 8),
          Text('Stop Scanning'),
        ],
      );
    }

    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search),
        SizedBox(width: 8),
        Text('Start Scanning'),
      ],
    );
  }
}
