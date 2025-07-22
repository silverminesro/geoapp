import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_providers.dart';
import '../widgets/inventory_items_list.dart';
import '../widgets/inventory_filter_dialog.dart';
import '../widgets/inventory_sort_dialog.dart';
import '../models/inventory_item_model.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen to tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tab = _tabController.index == 0 ? 'artifacts' : 'gear';
        ref.read(inventoryProvider.notifier).switchTab(tab);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Inventory',
              style: GameTextStyles.clockTime.copyWith(
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            if (inventoryState.isOfflineMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showSearchDialog,
            tooltip: 'Search items',
          ),
          // Filter button
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list, color: Colors.white),
                if (inventoryState.hasFiltersActive)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterDialog,
            tooltip: 'Filter items',
          ),
          // Sort button
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white),
            onPressed: _showSortDialog,
            tooltip: 'Sort items',
          ),
          // Refresh button
          IconButton(
            icon: inventoryState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: inventoryState.isLoading
                ? null
                : () => ref.read(inventoryProvider.notifier).refresh(),
            tooltip: 'Refresh inventory',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.diamond),
              text: 'Artifacts (${inventoryState.artifacts.length})',
            ),
            Tab(
              icon: const Icon(Icons.shield),
              text: 'Gear (${inventoryState.gear.length})',
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final inventoryState = ref.watch(inventoryProvider);

    if (inventoryState.isLoading && inventoryState.isEmpty) {
      return _buildLoadingState();
    }

    if (inventoryState.error != null && inventoryState.isEmpty) {
      return _buildErrorState(inventoryState.error!);
    }

    if (inventoryState.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Filters info bar
        if (inventoryState.hasFiltersActive) _buildFiltersBar(),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Artifacts tab
              InventoryItemsList(
                items: inventoryState.activeTab == 'artifacts'
                    ? inventoryState.filteredItems
                    : inventoryState.artifacts,
                itemType: 'artifacts',
                onItemTap: _onItemTap,
                isOffline: inventoryState.isOfflineMode,
              ),

              // Gear tab
              InventoryItemsList(
                items: inventoryState.activeTab == 'gear'
                    ? inventoryState.filteredItems
                    : inventoryState.gear,
                itemType: 'gear',
                onItemTap: _onItemTap,
                isOffline: inventoryState.isOfflineMode,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading inventory...',
            style: GameTextStyles.clockTime.copyWith(
              fontSize: 16,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch your items',
            style: GameTextStyles.clockLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: GameTextStyles.clockTime.copyWith(
                fontSize: 18,
                color: AppTheme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GameTextStyles.clockLabel.copyWith(
                color: Colors.red[300],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(inventoryProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(inventoryProvider.notifier).clearCache(),
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Cache'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final inventoryState = ref.watch(inventoryProvider);
    final isArtifactsTab = inventoryState.activeTab == 'artifacts';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isArtifactsTab ? Icons.diamond : Icons.shield,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isArtifactsTab ? 'No Artifacts Found' : 'No Gear Found',
              style: GameTextStyles.clockTime.copyWith(
                fontSize: 18,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArtifactsTab
                  ? 'Explore zones and scan for artifacts to build your collection!'
                  : 'Search zones for gear to equip and enhance your abilities!',
              style: GameTextStyles.clockLabel,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/map'),
              icon: const Icon(Icons.explore),
              label: const Text('Explore Zones'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersBar() {
    final inventoryState = ref.watch(inventoryProvider);
    final List<Widget> chips = [];

    if (inventoryState.searchQuery != null &&
        inventoryState.searchQuery!.isNotEmpty) {
      chips.add(_buildFilterChip(
        'Search: "${inventoryState.searchQuery}"',
        onDeleted: () =>
            ref.read(inventoryProvider.notifier).setSearchQuery(null),
      ));
    }

    if (inventoryState.filterRarity != null) {
      chips.add(_buildFilterChip(
        'Rarity: ${inventoryState.filterRarity}',
        onDeleted: () =>
            ref.read(inventoryProvider.notifier).setFilters(rarity: null),
      ));
    }

    if (inventoryState.filterBiome != null) {
      chips.add(_buildFilterChip(
        'Biome: ${inventoryState.filterBiome}',
        onDeleted: () =>
            ref.read(inventoryProvider.notifier).setFilters(biome: null),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.cardColor,
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: chips,
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(inventoryProvider.notifier).clearFilters(),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {VoidCallback? onDeleted}) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      side: BorderSide(color: AppTheme.primaryColor),
    );
  }

  void _onItemTap(InventoryItem item) {
    context.push('/inventory/detail', extra: item);
  }

  void _showSearchDialog() {
    final currentQuery = ref.read(inventoryProvider).searchQuery ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'Search Items',
          style: GameTextStyles.clockTime.copyWith(fontSize: 18),
        ),
        content: TextField(
          controller: TextEditingController(text: currentQuery),
          decoration: InputDecoration(
            hintText: 'Enter item name...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onSubmitted: (value) {
            ref
                .read(inventoryProvider.notifier)
                .setSearchQuery(value.trim().isEmpty ? null : value.trim());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(inventoryProvider.notifier).setSearchQuery(null);
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => InventoryFilterDialog(),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => InventorySortDialog(),
    );
  }
}
