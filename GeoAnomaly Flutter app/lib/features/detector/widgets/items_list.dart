// lib/features/detector/widgets/items_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/artifact_model.dart';
import '../models/detector_model.dart';
import '../models/detector_config.dart';
import '../providers/detection_provider.dart';
import '../models/detection_state.dart';

class ItemsList extends ConsumerStatefulWidget {
  final String zoneId;
  final Detector detector;
  final Function(DetectableItem)? onItemTap;
  final Function(DetectableItem)? onCollectTap;

  const ItemsList({
    super.key,
    required this.zoneId,
    required this.detector,
    this.onItemTap,
    this.onCollectTap,
  });

  @override
  ConsumerState<ItemsList> createState() => _ItemsListState();
}

class _ItemsListState extends ConsumerState<ItemsList> {
  String _sortBy = 'distance'; // distance, name, rarity, type
  String _filterType = 'all'; // all, artifact, gear
  bool _showOnlyCollectable = false;

  @override
  Widget build(BuildContext context) {
    final params = DetectionProviderParams(
        zoneId: widget.zoneId, detector: widget.detector);
    final allItems = ref.watch(detectionProvider(params)).allItems;
    final state = ref.watch(detectionProvider(params));

    // ✅ Filter and sort items
    final filteredItems = _getFilteredItems(allItems);
    final sortedItems = _getSortedItems(filteredItems);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // ✅ Header with controls
          _buildHeader(allItems.length, sortedItems.length),

          // ✅ Filter and sort controls
          _buildControls(),

          // ✅ Items list
          if (sortedItems.isEmpty)
            _buildEmptyState()
          else
            _buildItemsList(sortedItems, state),
        ],
      ),
    );
  }

  // ✅ Build header
  Widget _buildHeader(int totalItems, int filteredItems) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          Text(
            'Items Detected',
            style: GameTextStyles.cardTitle.copyWith(fontSize: 16),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$filteredItems / $totalItems',
              style: GameTextStyles.cardSubtitle.copyWith(
                fontSize: 12,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Build filter and sort controls
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        children: [
          // First row - Type filter and sort
          Row(
            children: [
              // Type filter
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Filter:',
                      style: GameTextStyles.cardSubtitle.copyWith(fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _filterType,
                      isDense: true,
                      style: GameTextStyles.cardSubtitle.copyWith(fontSize: 12),
                      dropdownColor: AppTheme.cardColor,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                            value: 'artifact', child: Text('Artifacts')),
                        DropdownMenuItem(value: 'gear', child: Text('Gear')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _filterType = value);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Sort dropdown
              Row(
                children: [
                  Text(
                    'Sort:',
                    style: GameTextStyles.cardSubtitle.copyWith(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _sortBy,
                    isDense: true,
                    style: GameTextStyles.cardSubtitle.copyWith(fontSize: 12),
                    dropdownColor: AppTheme.cardColor,
                    items: const [
                      DropdownMenuItem(
                          value: 'distance', child: Text('Distance')),
                      DropdownMenuItem(value: 'name', child: Text('Name')),
                      DropdownMenuItem(value: 'rarity', child: Text('Rarity')),
                      DropdownMenuItem(value: 'type', child: Text('Type')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _sortBy = value);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Second row - Collectable filter
          Row(
            children: [
              Checkbox(
                value: _showOnlyCollectable,
                onChanged: (value) {
                  setState(() => _showOnlyCollectable = value ?? false);
                },
                activeColor: AppTheme.primaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() => _showOnlyCollectable = !_showOnlyCollectable);
                },
                child: Text(
                  'Show only collectable items (≤${DetectorConfig.collectionRadius}m)',
                  style: GameTextStyles.cardSubtitle.copyWith(fontSize: 12),
                ),
              ),
              if (DetectorConfig.isDebugMode) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
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
        ],
      ),
    );
  }

  // ✅ Build items list
  Widget _buildItemsList(List<DetectableItem> items, DetectionState state) {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildItemTile(item, state);
        },
      ),
    );
  }

  // ✅ Build individual item tile
  Widget _buildItemTile(DetectableItem item, DetectionState state) {
    final notifier = ref.read(detectionProvider(DetectionProviderParams(
            zoneId: widget.zoneId, detector: widget.detector))
        .notifier);

    final isClosestItem = state.closestItem?.id == item.id;
    final canCollect =
        !state.isCollecting && item.isVeryClose && item.canBeDetected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isClosestItem
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isClosestItem
              ? AppTheme.primaryColor.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),

        // ✅ Leading icon with rarity color
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _getRarityColor(item.rarity).withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _getRarityColor(item.rarity)),
          ),
          child: Icon(
            _getItemIcon(item.type),
            color: _getRarityColor(item.rarity),
            size: 20,
          ),
        ),

        // ✅ Title and subtitle
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: GameTextStyles.cardTitle.copyWith(
                  fontSize: 14,
                  fontWeight:
                      isClosestItem ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isClosestItem)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'CLOSEST',
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${item.type.toUpperCase()} • ${item.rarityDisplayName}',
                  style: GameTextStyles.cardSubtitle.copyWith(fontSize: 11),
                ),
                if (item.distanceFromPlayer != null) ...[
                  const Text(' • '),
                  Text(
                    item.distanceDisplay,
                    style: GameTextStyles.cardSubtitle.copyWith(
                      fontSize: 11,
                      color: item.isVeryClose
                          ? Colors.green
                          : item.isClose
                              ? Colors.orange
                              : AppTheme.textSecondaryColor,
                      fontWeight: item.isVeryClose
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  const Text(' • '),
                  Text(
                    item.compassDirectionDisplay,
                    style: GameTextStyles.cardSubtitle.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
            if (DetectorConfig.isDebugMode) ...[
              const SizedBox(height: 2),
              Text(
                'ID: ${item.id} • ${item.debugProximityInfo}',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.orange[700],
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),

        // ✅ Trailing actions
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicators
            if (item.isVeryClose)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              )
            else if (item.isClose)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),

            const SizedBox(width: 8),

            // Collect button
            if (canCollect)
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: state.isCollecting
                      ? null
                      : () {
                          notifier.collectItem(item);
                          widget.onCollectTap?.call(item);
                        },
                  icon: state.isCollecting && state.closestItem?.id == item.id
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download, size: 16),
                  color: Colors.green,
                  tooltip: 'Collect Item',
                ),
              )
            else
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: () => widget.onItemTap?.call(item),
                  icon: const Icon(Icons.info_outline, size: 16),
                  color: AppTheme.textSecondaryColor,
                  tooltip: 'Item Info',
                ),
              ),
          ],
        ),

        onTap: () => widget.onItemTap?.call(item),
      ),
    );
  }

  // ✅ Build empty state
  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                _getEmptyStateText(),
                style: GameTextStyles.cardSubtitle.copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _clearFilters(),
                child: Text(
                  'Clear Filters',
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Filter items based on current settings
  List<DetectableItem> _getFilteredItems(List<DetectableItem> items) {
    List<DetectableItem> filtered = items;

    // Filter by type
    if (_filterType != 'all') {
      filtered = filtered.where((item) => item.type == _filterType).toList();
    }

    // Filter by collectable
    if (_showOnlyCollectable) {
      filtered = filtered.where((item) => item.isVeryClose).toList();
    }

    return filtered;
  }

  // ✅ Sort items based on current setting
  List<DetectableItem> _getSortedItems(List<DetectableItem> items) {
    List<DetectableItem> sorted = List.from(items);

    switch (_sortBy) {
      case 'distance':
        sorted.sort((a, b) {
          final distA = a.distanceFromPlayer ?? double.infinity;
          final distB = b.distanceFromPlayer ?? double.infinity;
          return distA.compareTo(distB);
        });
        break;
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'rarity':
        sorted.sort((a, b) =>
            _getRarityOrder(b.rarity).compareTo(_getRarityOrder(a.rarity)));
        break;
      case 'type':
        sorted.sort((a, b) => a.type.compareTo(b.type));
        break;
    }

    return sorted;
  }

  // ✅ Get rarity order for sorting
  int _getRarityOrder(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return 5;
      case 'epic':
        return 4;
      case 'rare':
        return 3;
      case 'uncommon':
        return 2;
      case 'common':
        return 1;
      default:
        return 0;
    }
  }

  // ✅ Get empty state text
  String _getEmptyStateText() {
    if (_showOnlyCollectable) {
      return 'No items within collection range\n(≤${DetectorConfig.collectionRadius}m)';
    }
    if (_filterType != 'all') {
      return 'No ${_filterType}s found\nwith current filters';
    }
    return 'No items detected\nStart scanning to find artifacts';
  }

  // ✅ Clear all filters
  void _clearFilters() {
    setState(() {
      _filterType = 'all';
      _showOnlyCollectable = false;
      _sortBy = 'distance';
    });
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
        return Colors.grey;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  // ✅ Get item type icon
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
