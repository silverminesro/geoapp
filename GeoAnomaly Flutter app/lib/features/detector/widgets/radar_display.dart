// lib/features/detector/widgets/radar_display.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../core/theme/app_theme.dart';
import '../models/detector_model.dart';
import '../models/detector_config.dart';
import '../models/artifact_model.dart';
import '../providers/detection_provider.dart';

class RadarDisplay extends ConsumerStatefulWidget {
  final String zoneId;
  final Detector detector;

  const RadarDisplay({
    super.key,
    required this.zoneId,
    required this.detector,
  });

  @override
  ConsumerState<RadarDisplay> createState() => _RadarDisplayState();
}

class _RadarDisplayState extends ConsumerState<RadarDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;
  late Animation<double> _sweepAnimation;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      duration: DetectorConfig.SCAN_ANIMATION_DURATION,
      vsync: this,
    );

    _sweepAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _sweepController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = DetectionProviderParams(
        zoneId: widget.zoneId, detector: widget.detector);
    final isScanning = ref.watch(isDetectionScanningProvider(params));
    final radarItems = ref.watch(radarPositionsProvider(params));

    // ✅ Control sweep animation
    if (isScanning) {
      if (!_sweepController.isAnimating) {
        _sweepController.repeat();
      }
    } else {
      _sweepController.stop();
      _sweepController.reset();
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
          // ✅ Radar title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Radar Display',
                style: GameTextStyles.cardTitle.copyWith(fontSize: 14),
              ),
              Text(
                'Range: ${widget.detector.maxRangeMeters.toInt()}m',
                style: GameTextStyles.cardSubtitle.copyWith(fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ✅ Radar display
          Center(
            child: Container(
              width: DetectorConfig.RADAR_DISPLAY_SIZE,
              height: DetectorConfig.RADAR_DISPLAY_SIZE,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.3),
                border:
                    Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
              ),
              child: AnimatedBuilder(
                animation: _sweepAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(DetectorConfig.RADAR_DISPLAY_SIZE,
                        DetectorConfig.RADAR_DISPLAY_SIZE),
                    painter: RadarPainter(
                      sweepAngle: isScanning ? _sweepAnimation.value : 0,
                      items: radarItems,
                      isScanning: isScanning,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ Legend
          if (radarItems.isNotEmpty) _buildLegend(radarItems),
        ],
      ),
    );
  }

  // ✅ Build legend
  Widget _buildLegend(List<Map<String, dynamic>> radarItems) {
    final uniqueTypes = <String>{};
    for (final itemData in radarItems) {
      final item = itemData['item'] as DetectableItem;
      uniqueTypes.add(item.type);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: uniqueTypes.map((type) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getItemTypeColor(type),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                type.toUpperCase(),
                style: GameTextStyles.cardSubtitle.copyWith(fontSize: 10),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ✅ Get item type color
  Color _getItemTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'artifact':
        return Colors.purple;
      case 'gear':
        return Colors.orange;
      default:
        return Colors.white;
    }
  }
}

// ✅ Custom painter for radar
class RadarPainter extends CustomPainter {
  final double sweepAngle;
  final List<Map<String, dynamic>> items;
  final bool isScanning;

  RadarPainter({
    required this.sweepAngle,
    required this.items,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ✅ Draw range rings
    final ringPaint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= DetectorConfig.RADAR_RINGS; i++) {
      final ringRadius = (radius * i) / DetectorConfig.RADAR_RINGS;
      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // ✅ Draw cardinal directions
    final directionPaint = Paint()
      ..color = AppTheme.textSecondaryColor.withOpacity(0.6)
      ..strokeWidth = 1;

    // North
    canvas.drawLine(
      Offset(center.dx, center.dy - radius + 5),
      Offset(center.dx, center.dy - radius + 15),
      directionPaint,
    );

    // East
    canvas.drawLine(
      Offset(center.dx + radius - 15, center.dy),
      Offset(center.dx + radius - 5, center.dy),
      directionPaint,
    );

    // ✅ Draw sweep line (if scanning)
    if (isScanning) {
      final sweepPaint = Paint()
        ..color = AppTheme.primaryColor.withOpacity(0.7)
        ..strokeWidth = 2;

      final sweepEnd = Offset(
        center.dx + radius * math.cos(sweepAngle - math.pi / 2),
        center.dy + radius * math.sin(sweepAngle - math.pi / 2),
      );

      canvas.drawLine(center, sweepEnd, sweepPaint);

      // Sweep gradient
      final sweepGradient = Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.3),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        sweepAngle - math.pi / 4,
        math.pi / 4,
        true,
        sweepGradient,
      );
    }

    // ✅ Draw items
    for (final itemData in items) {
      final item = itemData['item'] as DetectableItem;
      final x = itemData['x'] as double;
      final y = itemData['y'] as double;
      final isVeryClose = itemData['isVeryClose'] as bool;
      final isClose = itemData['isClose'] as bool;

      final itemPosition = Offset(center.dx + x, center.dy + y);

      // Item color based on type and proximity
      Color itemColor = _getItemColor(item.type);
      if (isVeryClose) {
        itemColor = Colors.green;
      } else if (isClose) {
        itemColor = Colors.orange;
      }

      final itemPaint = Paint()
        ..color = itemColor
        ..style = PaintingStyle.fill;

      // Draw item with size based on proximity
      final itemSize = isVeryClose
          ? 6.0
          : isClose
              ? 4.0
              : 3.0;
      canvas.drawCircle(itemPosition, itemSize, itemPaint);

      // Draw pulsing effect for very close items
      if (isVeryClose) {
        final pulsePaint = Paint()
          ..color = itemColor.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(itemPosition, itemSize + 2, pulsePaint);
      }
    }

    // ✅ Draw center (player position)
    final playerPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, playerPaint);

    // Player indicator ring
    final playerRingPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 8, playerRingPaint);
  }

  // ✅ Get item color by type
  Color _getItemColor(String type) {
    switch (type.toLowerCase()) {
      case 'artifact':
        return Colors.purple;
      case 'gear':
        return Colors.orange;
      default:
        return Colors.white;
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return sweepAngle != oldDelegate.sweepAngle ||
        items.length != oldDelegate.items.length ||
        isScanning != oldDelegate.isScanning;
  }
}
