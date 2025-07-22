import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/inventory_service.dart';
import '../services/inventory_cache_service.dart';
import '../models/inventory_item_model.dart';
import '../models/artifact_item_model.dart';
import '../models/gear_item_model.dart';
import '../models/inventory_summary_model.dart';

// Service providers
final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService();
});

final inventoryCacheServiceProvider = Provider<InventoryCacheService>((ref) {
  return InventoryCacheService();
});

// State class for inventory
class InventoryState {
  final List<InventoryItem> allItems;
  final List<InventoryItem> artifacts;
  final List<InventoryItem> gear;
  final InventorySummary? summary;
  final Map<String, dynamic> detailedItems; // Cache for detailed items
  final bool isLoading;
  final bool isOfflineMode;
  final String? error;
  final String activeTab; // 'artifacts' or 'gear'
  final String sortBy;
  final String sortOrder;
  final String? filterRarity;
  final String? filterBiome;
  final String? searchQuery;
  final DateTime? lastUpdated; // ✅ ADDED: Track last update time

  const InventoryState({
    this.allItems = const [],
    this.artifacts = const [],
    this.gear = const [],
    this.summary,
    this.detailedItems = const {},
    this.isLoading = false,
    this.isOfflineMode = false,
    this.error,
    this.activeTab = 'artifacts',
    this.sortBy = 'acquired_at',
    this.sortOrder = 'desc',
    this.filterRarity,
    this.filterBiome,
    this.searchQuery,
    this.lastUpdated, // ✅ ADDED
  });

  InventoryState copyWith({
    List<InventoryItem>? allItems,
    List<InventoryItem>? artifacts,
    List<InventoryItem>? gear,
    InventorySummary? summary,
    Map<String, dynamic>? detailedItems,
    bool? isLoading,
    bool? isOfflineMode,
    String? error,
    String? activeTab,
    String? sortBy,
    String? sortOrder,
    String? filterRarity,
    String? filterBiome,
    String? searchQuery,
    DateTime? lastUpdated, // ✅ ADDED
  }) {
    return InventoryState(
      allItems: allItems ?? this.allItems,
      artifacts: artifacts ?? this.artifacts,
      gear: gear ?? this.gear,
      summary: summary ?? this.summary,
      detailedItems: detailedItems ?? this.detailedItems,
      isLoading: isLoading ?? this.isLoading,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      error: error ?? this.error,
      activeTab: activeTab ?? this.activeTab,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      filterRarity: filterRarity ?? this.filterRarity,
      filterBiome: filterBiome ?? this.filterBiome,
      searchQuery: searchQuery ?? this.searchQuery,
      lastUpdated: lastUpdated ?? this.lastUpdated, // ✅ ADDED
    );
  }

  // Helper getters
  List<InventoryItem> get currentTabItems {
    return activeTab == 'artifacts' ? artifacts : gear;
  }

  List<InventoryItem> get filteredItems {
    return _applyFilters(currentTabItems);
  }

  bool get isEmpty => allItems.isEmpty;
  bool get hasArtifacts => artifacts.isNotEmpty;
  bool get hasGear => gear.isNotEmpty;
  bool get hasFiltersActive =>
      filterRarity != null || filterBiome != null || searchQuery != null;

  // Apply filters and search
  List<InventoryItem> _applyFilters(List<InventoryItem> items) {
    var filtered = List<InventoryItem>.from(items);

    // Apply search query
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      filtered = filtered.where((item) {
        final name = item.displayName.toLowerCase();
        final query = searchQuery!.toLowerCase();
        return name.contains(query);
      }).toList();
    }

    // Apply rarity filter
    if (filterRarity != null && filterRarity!.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.rarity.toLowerCase() == filterRarity!.toLowerCase();
      }).toList();
    }

    // Apply biome filter (would need biome info in properties or detailed items)
    if (filterBiome != null && filterBiome!.isNotEmpty) {
      filtered = filtered.where((item) {
        final biome = item.getProperty<String>('biome');
        return biome?.toLowerCase() == filterBiome!.toLowerCase();
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;

      switch (sortBy) {
        case 'name':
          comparison = a.displayName.compareTo(b.displayName);
          break;
        case 'acquired_at':
          comparison = a.acquiredAt.compareTo(b.acquiredAt);
          break;
        case 'rarity':
          comparison = _getRarityPriority(a.rarity)
              .compareTo(_getRarityPriority(b.rarity));
          break;
        case 'quantity':
          comparison = a.quantity.compareTo(b.quantity);
          break;
        default:
          comparison = a.acquiredAt.compareTo(b.acquiredAt);
      }

      return sortOrder == 'desc' ? -comparison : comparison;
    });

    return filtered;
  }

  int _getRarityPriority(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return 4;
      case 'epic':
        return 3;
      case 'rare':
        return 2;
      case 'common':
        return 1;
      default:
        return 0;
    }
  }
}

// Inventory Notifier
class InventoryNotifier extends StateNotifier<InventoryState> {
  final InventoryService _inventoryService;
  final InventoryCacheService _cacheService;

  InventoryNotifier(this._inventoryService, this._cacheService)
      : super(const InventoryState()) {
    // Load inventory on initialization
    loadInventory();
  }

  // ✅ ADDED: Clear error method
  void clearError() {
    print('🗑️ Clearing error state');
    state = state.copyWith(error: null);
  }

  // Load inventory items
  Future<void> loadInventory({bool forceRefresh = false}) async {
    print('📦 Loading inventory (forceRefresh: $forceRefresh)...');

    state = state.copyWith(isLoading: true, error: null);

    try {
      List<InventoryItem> items = [];
      InventorySummary? summary;

      // Try to load from network first
      if (forceRefresh || !state.isOfflineMode) {
        try {
          print('🌐 Attempting to load from network...');

          final results = await Future.wait([
            _inventoryService.getInventoryItems(),
            _inventoryService.getInventorySummary(),
          ]);

          items = results[0] as List<InventoryItem>;
          summary = results[1] as InventorySummary;

          // Cache for offline use
          await _cacheService.cacheInventoryItems(items);
          await _cacheService.cacheInventorySummary(summary);
          await _cacheService.updateLastSyncTime();

          print('✅ Loaded ${items.length} items from network');
          _updateStateWithItems(items, summary, isOffline: false);
        } catch (networkError) {
          print('❌ Network error, falling back to cache: $networkError');

          // Fall back to cache if network fails
          final cachedItems = await _cacheService.getCachedInventoryItems();
          final cachedSummary = await _cacheService.getCachedInventorySummary();

          if (cachedItems != null && cachedItems.isNotEmpty) {
            print('✅ Loaded ${cachedItems.length} items from cache');
            _updateStateWithItems(cachedItems, cachedSummary, isOffline: true);
          } else {
            throw Exception('No cached data available and network failed');
          }
        }
      } else {
        // Load from cache when in offline mode
        print('📱 Loading from cache (offline mode)...');
        final cachedItems = await _cacheService.getCachedInventoryItems();
        final cachedSummary = await _cacheService.getCachedInventorySummary();

        if (cachedItems != null && cachedItems.isNotEmpty) {
          print(
              '✅ Loaded ${cachedItems.length} items from cache (offline mode)');
          _updateStateWithItems(cachedItems, cachedSummary, isOffline: true);
        } else {
          throw Exception('No cached data available');
        }
      }
    } catch (e) {
      print('❌ Failed to load inventory: $e');
      state = state.copyWith(
        error: e.toString().replaceAll('Exception: ', ''),
        isLoading: false,
      );
    }
  }

  // Update state with items
  void _updateStateWithItems(
    List<InventoryItem> items,
    InventorySummary? summary, {
    required bool isOffline,
  }) {
    final artifacts = items.where((item) => item.isArtifact).toList();
    final gear = items.where((item) => item.isGear).toList();

    state = state.copyWith(
      allItems: items,
      artifacts: artifacts,
      gear: gear,
      summary: summary,
      isLoading: false,
      isOfflineMode: isOffline,
      error: null,
      lastUpdated: DateTime.now(), // ✅ ADDED: Track update time
    );

    print(
        '📊 State updated: ${artifacts.length} artifacts, ${gear.length} gear (offline: $isOffline)');
  }

  // Get detailed item information
  Future<dynamic> getItemDetails(InventoryItem inventoryItem) async {
    final cacheKey = '${inventoryItem.itemType}_${inventoryItem.itemId}';

    print('🔍 Getting details for: ${inventoryItem.displayName} ($cacheKey)');

    // Check memory cache first
    if (state.detailedItems.containsKey(cacheKey)) {
      print('✅ Found in memory cache');
      return state.detailedItems[cacheKey];
    }

    try {
      dynamic detailedItem;

      // Try to load from network
      if (!state.isOfflineMode) {
        if (inventoryItem.isArtifact) {
          detailedItem =
              await _inventoryService.getArtifactDetails(inventoryItem.itemId);
          await _cacheService.cacheArtifactDetails(
              inventoryItem.itemId, detailedItem as ArtifactItem);
        } else {
          detailedItem =
              await _inventoryService.getGearDetails(inventoryItem.itemId);
          await _cacheService.cacheGearDetails(
              inventoryItem.itemId, detailedItem as GearItem);
        }

        print('✅ Loaded details from network: ${detailedItem.name}');
      } else {
        // Load from cache when offline
        if (inventoryItem.isArtifact) {
          detailedItem = await _cacheService
              .getCachedArtifactDetails(inventoryItem.itemId);
        } else {
          detailedItem =
              await _cacheService.getCachedGearDetails(inventoryItem.itemId);
        }

        if (detailedItem == null) {
          throw Exception('Item details not available offline');
        }

        print('✅ Loaded details from cache: ${detailedItem.name}');
      }

      // Update memory cache
      final updatedCache = Map<String, dynamic>.from(state.detailedItems);
      updatedCache[cacheKey] = detailedItem;
      state = state.copyWith(detailedItems: updatedCache);

      return detailedItem;
    } catch (e) {
      print('❌ Failed to get item details: $e');

      // Try cache as last resort
      if (!state.isOfflineMode) {
        try {
          dynamic cachedItem;
          if (inventoryItem.isArtifact) {
            cachedItem = await _cacheService
                .getCachedArtifactDetails(inventoryItem.itemId);
          } else {
            cachedItem =
                await _cacheService.getCachedGearDetails(inventoryItem.itemId);
          }

          if (cachedItem != null) {
            print('✅ Fell back to cached details: ${cachedItem.name}');
            final updatedCache = Map<String, dynamic>.from(state.detailedItems);
            updatedCache[cacheKey] = cachedItem;
            state = state.copyWith(detailedItems: updatedCache);
            return cachedItem;
          }
        } catch (cacheError) {
          print('❌ Cache fallback also failed: $cacheError');
        }
      }

      throw Exception('Unable to load item details: $e');
    }
  }

  // Switch active tab
  void switchTab(String tab) {
    if (tab == 'artifacts' || tab == 'gear') {
      print('📑 Switching to $tab tab');
      state = state.copyWith(activeTab: tab);
    }
  }

  // Set filters
  void setFilters({String? rarity, String? biome}) {
    print('🔍 Setting filters - rarity: $rarity, biome: $biome');
    state = state.copyWith(
      filterRarity: rarity,
      filterBiome: biome,
    );
  }

  // Clear filters
  void clearFilters() {
    print('🗑️ Clearing all filters');
    state = state.copyWith(
      filterRarity: null,
      filterBiome: null,
      searchQuery: null,
    );
  }

  // Set search query
  void setSearchQuery(String? query) {
    print('🔍 Setting search query: $query');
    state = state.copyWith(searchQuery: query);
  }

  // Set sorting
  void setSortBy(String sortBy, {String? sortOrder}) {
    print('📊 Setting sort: $sortBy ${sortOrder ?? state.sortOrder}');
    state = state.copyWith(
      sortBy: sortBy,
      sortOrder: sortOrder ?? state.sortOrder,
    );
  }

  // Toggle sort order
  void toggleSortOrder() {
    final newOrder = state.sortOrder == 'asc' ? 'desc' : 'asc';
    print('🔄 Toggling sort order to: $newOrder');
    state = state.copyWith(sortOrder: newOrder);
  }

  // Item actions
  Future<void> removeItem(InventoryItem item) async {
    try {
      print('🗑️ Removing item: ${item.displayName}');

      await _inventoryService.removeItem(item.id);

      // Refresh inventory
      await loadInventory(forceRefresh: true);

      print('✅ Item removed successfully');
    } catch (e) {
      print('❌ Failed to remove item: $e');
      throw Exception('Failed to remove item: $e');
    }
  }

  Future<void> useItem(InventoryItem item) async {
    try {
      print('🎯 Using item: ${item.displayName}');

      final result = await _inventoryService.useItem(item.id);

      // Refresh inventory
      await loadInventory(forceRefresh: true);

      print('✅ Item used successfully: $result');
    } catch (e) {
      print('❌ Failed to use item: $e');
      throw Exception('Failed to use item: $e');
    }
  }

  Future<void> toggleFavorite(InventoryItem item, bool favorite) async {
    try {
      print('⭐ Toggling favorite for: ${item.displayName} to $favorite');

      await _inventoryService.toggleFavorite(item.id, favorite);

      // Update item in state (could be optimistic update)
      // For now, refresh inventory
      await loadInventory(forceRefresh: true);

      print('✅ Favorite status updated');
    } catch (e) {
      print('❌ Failed to update favorite: $e');
      throw Exception('Failed to update favorite status: $e');
    }
  }

  // Refresh methods
  Future<void> refresh() async {
    print('🔄 Manual refresh triggered');
    await loadInventory(forceRefresh: true);
  }

  Future<void> refreshIfStale() async {
    // Only refresh if data is older than 5 minutes
    final lastSync = await _cacheService.getLastSyncTime();
    if (lastSync == null || DateTime.now().difference(lastSync).inMinutes > 5) {
      print('🔄 Data is stale, refreshing...');
      await loadInventory(forceRefresh: true);
    }
  }

  // Clear cache
  Future<void> clearCache() async {
    try {
      print('🗑️ Clearing inventory cache...');
      await _cacheService.clearAllCache();

      // Clear memory cache too
      state = state.copyWith(detailedItems: {});

      print('✅ Cache cleared');
    } catch (e) {
      print('❌ Failed to clear cache: $e');
    }
  }

  // Get cache info
  Future<Map<String, dynamic>> getCacheInfo() async {
    return await _cacheService.getCacheInfo();
  }
}

// Main inventory provider
final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  final inventoryService = ref.watch(inventoryServiceProvider);
  final cacheService = ref.watch(inventoryCacheServiceProvider);
  return InventoryNotifier(inventoryService, cacheService);
});

// Convenience providers for easier access
final currentUserInventoryProvider = Provider<List<InventoryItem>>((ref) {
  return ref.watch(inventoryProvider).allItems;
});

final artifactsProvider = Provider<List<InventoryItem>>((ref) {
  return ref.watch(inventoryProvider).artifacts;
});

final gearProvider = Provider<List<InventoryItem>>((ref) {
  return ref.watch(inventoryProvider).gear;
});

final filteredItemsProvider = Provider<List<InventoryItem>>((ref) {
  return ref.watch(inventoryProvider).filteredItems;
});

final inventorySummaryProvider = Provider<InventorySummary?>((ref) {
  return ref.watch(inventoryProvider).summary;
});

final isInventoryLoadingProvider = Provider<bool>((ref) {
  return ref.watch(inventoryProvider).isLoading;
});

final isOfflineModeProvider = Provider<bool>((ref) {
  return ref.watch(inventoryProvider).isOfflineMode;
});

final inventoryErrorProvider = Provider<String?>((ref) {
  return ref.watch(inventoryProvider).error;
});

final activeTabProvider = Provider<String>((ref) {
  return ref.watch(inventoryProvider).activeTab;
});

final hasInventoryFiltersProvider = Provider<bool>((ref) {
  return ref.watch(inventoryProvider).hasFiltersActive;
});

// Specific item detail provider
final itemDetailsProvider =
    FutureProvider.family<dynamic, InventoryItem>((ref, item) async {
  final notifier = ref.watch(inventoryProvider.notifier);
  return await notifier.getItemDetails(item);
});
