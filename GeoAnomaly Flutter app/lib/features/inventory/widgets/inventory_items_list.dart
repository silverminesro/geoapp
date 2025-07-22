import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/inventory_item_model.dart';
import 'inventory_item_card.dart';

class InventoryItemsList extends ConsumerWidget {
  final List<InventoryItem> items;
  final String itemType;
  final Function(InventoryItem) onItemTap;
  final bool isOffline;

  const InventoryItemsList({
    super.key,
    required this.items,
    required this.itemType,
    required this.onItemTap,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Only refresh if not offline
        if (!isOffline) {
          // Trigger refresh from provider
          // This would be handled by the parent screen
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InventoryItemCard(
              item: item,
              onTap: () => onItemTap(item),
              showOfflineIndicator: isOffline,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isArtifacts = itemType == 'artifacts';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isArtifacts ? Icons.diamond : Icons.shield,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isArtifacts ? 'No Artifacts' : 'No Gear',
              style: GameTextStyles.header.copyWith(
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArtifacts
                  ? 'Discover artifacts by exploring zones!'
                  : 'Find gear by searching zones!',
              style: GameTextStyles.cardSubtitle,
              textAlign: TextAlign.center,
            ),
            if (isOffline) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Offline - showing cached data',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
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
}
