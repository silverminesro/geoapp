// lib/features/detector/widgets/detector_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/detector_model.dart';
import '../models/detector_config.dart';
import '../providers/detection_provider.dart';

class DetectorHeader extends ConsumerWidget {
  final Detector detector;
  final String zoneId;
  final VoidCallback? onExitPressed;

  const DetectorHeader({
    super.key,
    required this.detector,
    required this.zoneId,
    this.onExitPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = DetectionProviderParams(zoneId: zoneId, detector: detector);
    final state = ref.watch(detectionProvider(params));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
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
        children: [
          // ✅ Top row with detector info and exit button
          Row(
            children: [
              // Detector icon and rarity
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: detector.rarity.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: detector.rarity.color),
                ),
                child: Icon(
                  detector.icon,
                  color: detector.rarity.color,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              // Detector name and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            detector.name,
                            style: GameTextStyles.cardTitle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Rarity badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: detector.rarity.color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            detector.rarity.displayName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detector.description,
                      style: GameTextStyles.cardSubtitle.copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Exit button
              IconButton(
                onPressed: onExitPressed,
                icon: const Icon(Icons.close),
                color: Colors.grey[400],
                tooltip: 'Exit Detector',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ Detector stats
          Row(
            children: [
              Expanded(child: _buildStatBar('Range', detector.range)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatBar('Precision', detector.precision)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatBar('Battery', detector.battery)),
            ],
          ),

          const SizedBox(height: 12),

          // ✅ Status and debug info
          Row(
            children: [
              Expanded(
                child: Text(
                  state.statusMessage,
                  style: GameTextStyles.cardSubtitle.copyWith(
                    fontSize: 13,
                    color: state.hasError ? Colors.red : AppTheme.textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (DetectorConfig.isDebugMode) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange, width: 0.5),
                  ),
                  child: Text(
                    'DEBUG',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // ✅ Special ability info
          if (detector.specialAbility != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_fix_high,
                    color: AppTheme.primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      detector.specialAbility!,
                      style: GameTextStyles.cardSubtitle.copyWith(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontStyle: FontStyle.italic,
                      ),
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

  // ✅ Build stat bar widget
  Widget _buildStatBar(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GameTextStyles.cardSubtitle.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (index) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: index < value ? AppTheme.primaryColor : Colors.grey[600],
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        ),
      ],
    );
  }
}
