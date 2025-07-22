import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/inventory_item_model.dart';
import 'rarity_badge.dart';
import 'artifact_type_icon.dart';
import 'gear_type_icon.dart';

class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;
  final bool showOfflineIndicator;

  const InventoryItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.showOfflineIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Item icon
              _buildItemIcon(),

              const SizedBox(width: 16),

              // Item info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item name and quantity
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.displayName,
                            style: GameTextStyles.cardTitle.copyWith(
                              color: _getItemNameColor(),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.quantity > 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${item.quantity}x',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Item type and rarity
                    Row(
                      children: [
                        Text(
                          item.isArtifact ? 'Artifact' : 'Gear',
                          style: GameTextStyles.clockLabel.copyWith(
                            fontSize: 12,
                          ),
                        ),
                        Text(' • ', style: GameTextStyles.clockLabel),
                        Text(
                          _getSubtypeText(),
                          style: GameTextStyles.clockLabel.copyWith(
                            color: _getRarityColor(),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Acquired time
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeSinceAcquired(),
                          style: GameTextStyles.clockLabel.copyWith(
                            fontSize: 11,
                          ),
                        ),

                        const Spacer(),

                        // Offline indicator
                        if (showOfflineIndicator)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  size: 10,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'CACHED',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Rarity badge and arrow
              Column(
                children: [
                  RarityBadge(
                    rarity: item.rarity,
                    size: RarityBadgeSize.small,
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _getRarityColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getRarityColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: item.isArtifact
          ? ArtifactTypeIcon(
              type: item.getProperty<String>('type') ?? 'unknown',
              size: 28,
              color: _getRarityColor(),
            )
          : GearTypeIcon(
              type: item.getProperty<String>('type') ?? 'unknown',
              size: 28,
              color: _getRarityColor(),
            ),
    );
  }

  Color _getBorderColor() {
    return _getRarityColor().withOpacity(0.3);
  }

  Color _getItemNameColor() {
    return _getRarityColor();
  }

  Color _getRarityColor() {
    final rarity = item.rarity.toLowerCase();
    switch (rarity) {
      case 'legendary':
        return const Color(0xFFFF9800); // Orange
      case 'epic':
        return const Color(0xFF9C27B0); // Purple
      case 'rare':
        return const Color(0xFF2196F3); // Blue
      case 'common':
        return const Color(0xFF4CAF50); // Green
      default:
        return Colors.grey;
    }
  }

  String _getSubtypeText() {
    if (item.isArtifact) {
      final type = item.getProperty<String>('type') ?? 'Unknown';
      return '${_capitalizeFirst(type)} • ${_capitalizeFirst(item.rarity)}';
    } else {
      final level = item.getProperty<int>('level') ?? 1;
      return 'Level $level • ${_capitalizeFirst(item.rarity)}';
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _getTimeSinceAcquired() {
    final now = DateTime.now();
    final acquired = item.acquiredAt;
    final difference = now.difference(acquired);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
