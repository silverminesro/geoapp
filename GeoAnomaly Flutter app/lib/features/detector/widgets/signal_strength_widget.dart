// lib/features/detector/widgets/signal_strength_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/detector_config.dart';
import '../providers/detection_provider.dart';
import '../models/detector_model.dart';

class SignalStrengthWidget extends ConsumerStatefulWidget {
  final String zoneId;
  final Detector detector;

  const SignalStrengthWidget({
    super.key,
    required this.zoneId,
    required this.detector,
  });

  @override
  ConsumerState<SignalStrengthWidget> createState() =>
      _SignalStrengthWidgetState();
}

class _SignalStrengthWidgetState extends ConsumerState<SignalStrengthWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: DetectorConfig.SIGNAL_ANIMATION_DURATION,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = DetectionProviderParams(
        zoneId: widget.zoneId, detector: widget.detector);
    final signalStrength = ref.watch(signalStrengthProvider(params));
    final isScanning = ref.watch(isDetectionScanningProvider(params));
    final state = ref.watch(detectionProvider(params));

    // ✅ Animate when signal is strong
    if (signalStrength > 0.6 && isScanning) {
      if (!_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
      }
    } else {
      _animationController.stop();
      _animationController.reset();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // ✅ Signal strength title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Signal Strength',
                style: GameTextStyles.cardTitle.copyWith(fontSize: 14),
              ),
              Text(
                state.signalStrengthText,
                style: GameTextStyles.cardSubtitle.copyWith(
                  fontSize: 12,
                  color: _getSignalColor(signalStrength),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ✅ Signal bars
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: signalStrength > 0.6 ? _pulseAnimation.value : 1.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final barThreshold = (index + 1) / 5;
                    final isActive = signalStrength >= barThreshold;
                    final barHeight = 8.0 + (index * 3.0); // Progressive height

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 6,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: isActive
                            ? _getSignalColor(signalStrength)
                            : Colors.grey[700],
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: isActive && signalStrength > 0.8
                            ? [
                                BoxShadow(
                                  color: _getSignalColor(signalStrength)
                                      .withOpacity(0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // ✅ Distance and direction info
          if (state.closestItem != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.near_me,
                      size: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      state.closestItem!.distanceDisplay,
                      style: GameTextStyles.cardSubtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.explore,
                      size: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      state.direction,
                      style: GameTextStyles.cardSubtitle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],

          // ✅ Debug info
          if (DetectorConfig.isDebugMode && state.closestItem != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                state.closestItem!.debugProximityInfo,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange[700],
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ Get color based on signal strength
  Color _getSignalColor(double strength) {
    if (strength >= 0.8) return Colors.green;
    if (strength >= 0.6) return Colors.lightGreen;
    if (strength >= 0.4) return Colors.yellow;
    if (strength >= 0.2) return Colors.orange;
    if (strength > 0) return Colors.red;
    return Colors.grey;
  }
}
