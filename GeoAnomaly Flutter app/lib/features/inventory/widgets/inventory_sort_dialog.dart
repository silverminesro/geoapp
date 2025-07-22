import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_providers.dart';

class InventorySortDialog extends ConsumerStatefulWidget {
  const InventorySortDialog({super.key});

  @override
  ConsumerState<InventorySortDialog> createState() =>
      _InventorySortDialogState();
}

class _InventorySortDialogState extends ConsumerState<InventorySortDialog> {
  String _selectedSortBy = 'acquired_at';
  String _selectedSortOrder = 'desc';

  static const List<SortOption> _sortOptions = [
    SortOption('acquired_at', 'Date Acquired', Icons.access_time),
    SortOption('name', 'Name', Icons.sort_by_alpha),
    SortOption('rarity', 'Rarity', Icons.star),
    SortOption('quantity', 'Quantity', Icons.numbers),
  ];

  @override
  void initState() {
    super.initState();
    final currentState = ref.read(inventoryProvider);
    _selectedSortBy = currentState.sortBy;
    _selectedSortOrder = currentState.sortOrder;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.sort, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Sort Items',
                  style: GameTextStyles.clockTime.copyWith(
                    fontSize: 20,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Sort by options
            Text(
              'Sort By',
              style: GameTextStyles.clockTime.copyWith(
                fontSize: 14,
                color: AppTheme.textColor,
              ),
            ),

            const SizedBox(height: 12),

            ..._sortOptions.map((option) {
              return RadioListTile<String>(
                value: option.value,
                groupValue: _selectedSortBy,
                onChanged: (value) {
                  setState(() {
                    _selectedSortBy = value!;
                  });
                },
                title: Row(
                  children: [
                    Icon(
                      option.icon,
                      size: 18,
                      color: _selectedSortBy == option.value
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      option.label,
                      style: TextStyle(
                        color: _selectedSortBy == option.value
                            ? AppTheme.primaryColor
                            : AppTheme.textColor,
                      ),
                    ),
                  ],
                ),
                activeColor: AppTheme.primaryColor,
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),

            const SizedBox(height: 20),

            // Sort order
            Text(
              'Order',
              style: GameTextStyles.clockTime.copyWith(
                fontSize: 14,
                color: AppTheme.textColor,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildOrderOption(
                    'desc',
                    'Descending',
                    Icons.arrow_downward,
                    'Newest/Highest first',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOrderOption(
                    'asc',
                    'Ascending',
                    Icons.arrow_upward,
                    'Oldest/Lowest first',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applySort,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Apply Sort'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderOption(
    String value,
    String label,
    IconData icon,
    String description,
  ) {
    final isSelected = _selectedSortOrder == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSortOrder = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : AppTheme.backgroundColor,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textColor,
              ),
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _applySort() {
    ref.read(inventoryProvider.notifier).setSortBy(
          _selectedSortBy,
          sortOrder: _selectedSortOrder,
        );
    Navigator.pop(context);
  }
}

class SortOption {
  final String value;
  final String label;
  final IconData icon;

  const SortOption(this.value, this.label, this.icon);
}
