// lib/features/detector/widgets/collapsible_items_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/detector_model.dart';
import '../providers/detection_provider.dart';
import '../models/artifact_model.dart';
import 'items_list.dart';

class CollapsibleItemsList extends ConsumerStatefulWidget {
  final String zoneId;
  final Detector detector;
  final Function(DetectableItem)? onItemTap;
  final Function(DetectableItem)? onCollectTap;

  const CollapsibleItemsList({
    super.key,
    required this.zoneId,
    required this.detector,
    this.onItemTap,
    this.onCollectTap,
  });

  @override
  ConsumerState<CollapsibleItemsList> createState() =>
      _CollapsibleItemsListState();
}

class _CollapsibleItemsListState extends ConsumerState<CollapsibleItemsList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = Tween<double>(
      begin: 0.0,
      end: 300.0, // Max height
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = DetectionProviderParams(
        zoneId: widget.zoneId, detector: widget.detector);
    final allItems = ref.watch(detectionProvider(params)).allItems;

    return Column(
      children: [
        // ✅ Toggle button
        GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.list,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Items List (${allItems.length})',
                  style: GameTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ✅ Collapsible content
        AnimatedBuilder(
          animation: _heightAnimation,
          builder: (context, child) {
            return SizedBox(
              height: _heightAnimation.value,
              child: _heightAnimation.value > 0
                  ? ItemsList(
                      zoneId: widget.zoneId,
                      detector: widget.detector,
                      onItemTap: widget.onItemTap,
                      onCollectTap: widget.onCollectTap,
                    )
                  : null,
            );
          },
        ),
      ],
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }
}
