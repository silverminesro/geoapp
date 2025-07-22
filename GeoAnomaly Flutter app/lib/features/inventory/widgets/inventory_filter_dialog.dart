import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_providers.dart';

class InventoryFilterDialog extends ConsumerStatefulWidget {
  const InventoryFilterDialog({super.key});

  @override
  ConsumerState<InventoryFilterDialog> createState() =>
      _InventoryFilterDialogState();
}

class _InventoryFilterDialogState extends ConsumerState<InventoryFilterDialog> {
  String? _selectedRarity;
  String? _selectedBiome;

  static const List<String> _rarities = [
    'common',
    'rare',
    'epic',
    'legendary',
  ];

  static const List<String> _biomes = [
    'forest',
    'desert',
    'rocky',
    'wasteland',
    'swamp',
    'volcanic',
  ];

  @override
  void initState() {
    super.initState();
    final currentState = ref.read(inventoryProvider);
    _selectedRarity = currentState.filterRarity;
    _selectedBiome = currentState.filterBiome;
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
                Icon(Icons.filter_list, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Filter Items',
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

            // Rarity filter
            _buildFilterSection(
              title: 'Rarity',
              icon: Icons.star,
              child: _buildRarityFilter(),
            ),

            const SizedBox(height: 20),

            // Biome filter
            _buildFilterSection(
              title: 'Biome',
              icon: Icons.terrain,
              child: _buildBiomeFilter(),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearFilters,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text('Clear All'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: GameTextStyles.clockTime.copyWith(
                fontSize: 14,
                color: AppTheme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildRarityFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _rarities.map((rarity) {
        final isSelected = _selectedRarity == rarity;
        return FilterChip(
          label: Text(_capitalizeFirst(rarity)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedRarity = selected ? rarity : null;
            });
          },
          selectedColor: _getRarityColor(rarity).withOpacity(0.2),
          checkmarkColor: _getRarityColor(rarity),
          side: BorderSide(
            color: isSelected ? _getRarityColor(rarity) : AppTheme.borderColor,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBiomeFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _biomes.map((biome) {
        final isSelected = _selectedBiome == biome;
        return FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_getBiomeEmoji(biome)),
              const SizedBox(width: 4),
              Text(_capitalizeFirst(biome)),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedBiome = selected ? biome : null;
            });
          },
          selectedColor: AppTheme.primaryColor.withOpacity(0.2),
          checkmarkColor: AppTheme.primaryColor,
          side: BorderSide(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        );
      }).toList(),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedRarity = null;
      _selectedBiome = null;
    });
  }

  void _applyFilters() {
    ref.read(inventoryProvider.notifier).setFilters(
          rarity: _selectedRarity,
          biome: _selectedBiome,
        );
    Navigator.pop(context);
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return const Color(0xFFFF9800);
      case 'epic':
        return const Color(0xFF9C27B0);
      case 'rare':
        return const Color(0xFF2196F3);
      case 'common':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  String _getBiomeEmoji(String biome) {
    switch (biome.toLowerCase()) {
      case 'forest':
        return '🌲';
      case 'desert':
        return '🏜️';
      case 'rocky':
        return '🗿';
      case 'wasteland':
        return '☠️';
      case 'swamp':
        return '🐸';
      case 'volcanic':
        return '🌋';
      default:
        return '🌍';
    }
  }
}
