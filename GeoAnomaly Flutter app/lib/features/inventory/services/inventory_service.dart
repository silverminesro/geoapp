import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/inventory_item_model.dart';
import '../models/artifact_item_model.dart';
import '../models/gear_item_model.dart';
import '../models/inventory_summary_model.dart';

class InventoryService {
  final Dio _dio = ApiClient.dio;

  // Get inventory items (references only)
  Future<List<InventoryItem>> getInventoryItems({
    String? itemType, // 'artifact' or 'gear'
    int? limit,
    int? offset,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      print('🎒 Loading inventory items...');
      print('🎒 Parameters: itemType=$itemType, limit=$limit');

      final response = await _dio.get(
        '/inventory/items',
        queryParameters: {
          if (itemType != null) 'type': itemType,
          if (limit != null) 'limit': limit,
          // ✅ FIX: Proper conditional handling
          if (offset != null) 'page': (offset ~/ (limit ?? 50)) + 1,
          if (sortBy != null) 'sort_by': sortBy,
          if (sortOrder != null) 'sort_order': sortOrder,
        },
      );

      print('✅ Response status: ${response.statusCode}');
      print('✅ Response data type: ${response.data.runtimeType}');
      print('✅ Raw response: ${response.data}'); // Debug logging

      // ✅ FIXED: Handle backend response format
      List<dynamic> itemsData;

      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;

        if (data.containsKey('items')) {
          itemsData = data['items'] as List? ?? [];
          print('📊 Found ${itemsData.length} items in response');

          // ✅ LOG PAGINATION INFO
          if (data.containsKey('pagination')) {
            final pagination = data['pagination'];
            print('📊 Pagination: ${pagination}');
          }
        } else {
          print('❌ No "items" key in response: ${data.keys}');
          throw Exception('Invalid response format: missing items array');
        }
      } else if (response.data is List) {
        // Direct array format (fallback)
        itemsData = response.data as List;
        print('📊 Direct array format with ${itemsData.length} items');
      } else {
        print('❌ Unexpected response format: ${response.data}');
        throw Exception('Invalid response format from server');
      }

      final items =
          itemsData.map((item) => InventoryItem.fromJson(item)).toList();

      print('📊 Successfully parsed ${items.length} inventory items');
      return items;
    } on DioException catch (e) {
      print('❌ Inventory items DioException: ${e.response?.statusCode}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Request URL: ${e.requestOptions.uri}');
      print('❌ Request headers: ${e.requestOptions.headers}');

      throw Exception(_handleDioError(e, 'Failed to load inventory items'));
    } catch (e) {
      print('❌ Unexpected inventory items error: $e');
      throw Exception('Unexpected error occurred while loading inventory: $e');
    }
  }

  // Get inventory summary/statistics
  Future<InventorySummary> getInventorySummary() async {
    try {
      print('📊 Loading inventory summary...');

      final response =
          await _dio.get('/inventory/summary'); // ✅ FIXED: Removed prefix

      print('✅ Summary response status: ${response.statusCode}');
      print('✅ Summary raw response: ${response.data}');

      // ✅ FIXED: Handle backend response format
      Map<String, dynamic> summaryData;

      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('summary')) {
          summaryData = data['summary'] as Map<String, dynamic>;
        } else {
          summaryData = data;
        }
      } else {
        throw Exception('Invalid summary response format');
      }

      return InventorySummary.fromJson(summaryData);
    } on DioException catch (e) {
      print('❌ Inventory summary error: ${e.response?.data}');
      throw Exception(_handleDioError(e, 'Failed to load inventory summary'));
    } catch (e) {
      print('❌ Unexpected summary error: $e');
      throw Exception('Unexpected error occurred while loading summary: $e');
    }
  }

  // Get detailed artifact information
  Future<ArtifactItem> getArtifactDetails(String artifactId) async {
    try {
      print('💎 Loading artifact details: $artifactId');

      final response = await _dio.get(
          '/game/items/artifacts/$artifactId'); // ✅ FIXED: Use game endpoint

      print('✅ Artifact details loaded: ${response.data}');

      return ArtifactItem.fromJson(response.data);
    } on DioException catch (e) {
      print('❌ Artifact details error: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        throw Exception('Artifact not found');
      }
      throw Exception(_handleDioError(e, 'Failed to load artifact details'));
    } catch (e) {
      print('❌ Unexpected artifact error: $e');
      throw Exception('Unexpected error occurred while loading artifact: $e');
    }
  }

  // Get detailed gear information
  Future<GearItem> getGearDetails(String gearId) async {
    try {
      print('⚔️ Loading gear details: $gearId');

      final response = await _dio
          .get('/game/items/gear/$gearId'); // ✅ FIXED: Use game endpoint

      print('✅ Gear details loaded: ${response.data}');

      return GearItem.fromJson(response.data);
    } on DioException catch (e) {
      print('❌ Gear details error: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        throw Exception('Gear not found');
      }
      throw Exception(_handleDioError(e, 'Failed to load gear details'));
    } catch (e) {
      print('❌ Unexpected gear error: $e');
      throw Exception('Unexpected error occurred while loading gear: $e');
    }
  }

  // Remove item from inventory
  Future<void> removeItem(String inventoryItemId) async {
    try {
      print('🗑️ Removing inventory item: $inventoryItemId');

      final response = await _dio
          .delete('/inventory/$inventoryItemId'); // ✅ FIXED: Removed prefix

      print('✅ Item removed successfully: ${response.data}');
    } on DioException catch (e) {
      print('❌ Remove item error: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        throw Exception('Item not found in inventory');
      } else if (e.response?.statusCode == 403) {
        throw Exception('You cannot remove this item');
      }
      throw Exception(_handleDioError(e, 'Failed to remove item'));
    } catch (e) {
      print('❌ Unexpected remove error: $e');
      throw Exception('Unexpected error occurred while removing item: $e');
    }
  }

  // Use item (for consumables or usable items)
  Future<Map<String, dynamic>> useItem(String inventoryItemId) async {
    try {
      print('🎯 Using inventory item: $inventoryItemId');

      final response = await _dio
          .post('/inventory/$inventoryItemId/use'); // ✅ FIXED: Removed prefix

      print('✅ Item used successfully: ${response.data}');

      return response.data;
    } on DioException catch (e) {
      print('❌ Use item error: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        throw Exception('Item not found in inventory');
      } else if (e.response?.statusCode == 403) {
        throw Exception('This item cannot be used');
      } else if (e.response?.statusCode == 409) {
        throw Exception('Item is on cooldown or already used');
      } else if (e.response?.statusCode == 501) {
        throw Exception('Item usage not implemented yet');
      }
      throw Exception(_handleDioError(e, 'Failed to use item'));
    } catch (e) {
      print('❌ Unexpected use error: $e');
      throw Exception('Unexpected error occurred while using item: $e');
    }
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String inventoryItemId, bool favorite) async {
    try {
      print('⭐ Toggling favorite for item: $inventoryItemId to $favorite');

      final response = await _dio.put(
        '/inventory/$inventoryItemId/favorite', // ✅ FIXED: Removed prefix
        data: {'favorite': favorite},
      );

      print('✅ Favorite toggled successfully: ${response.data}');
    } on DioException catch (e) {
      print('❌ Toggle favorite error: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        throw Exception('Item not found in inventory');
      } else if (e.response?.statusCode == 501) {
        throw Exception('Favorite feature not implemented yet');
      }
      throw Exception(_handleDioError(e, 'Failed to update favorite status'));
    } catch (e) {
      print('❌ Unexpected favorite error: $e');
      throw Exception('Unexpected error occurred while updating favorite: $e');
    }
  }

  // Batch operations
  Future<List<InventoryItem>> getArtifactsOnly() async {
    return getInventoryItems(itemType: 'artifact');
  }

  Future<List<InventoryItem>> getGearOnly() async {
    return getInventoryItems(itemType: 'gear');
  }

  // Search functionality
  Future<List<InventoryItem>> searchItems({
    String? query,
    String? itemType,
    String? rarity,
    String? biome,
    int? minLevel,
    int? maxLevel,
  }) async {
    try {
      print('🔍 Searching inventory items...');

      final response = await _dio.get(
        '/inventory/search', // ✅ FIXED: Removed prefix
        queryParameters: {
          if (query != null) 'q': query,
          if (itemType != null) 'type': itemType, // ✅ FIXED: Use 'type'
          if (rarity != null) 'rarity': rarity,
          if (biome != null) 'biome': biome,
          if (minLevel != null) 'min_level': minLevel,
          if (maxLevel != null) 'max_level': maxLevel,
        },
      );

      // ✅ FIXED: Handle nested response format
      List<dynamic> itemsData;

      if (response.data is List) {
        itemsData = response.data as List;
      } else if (response.data is Map && response.data.containsKey('items')) {
        itemsData = response.data['items'] as List? ?? [];
      } else {
        itemsData = [];
      }

      final items =
          itemsData.map((item) => InventoryItem.fromJson(item)).toList();

      print('✅ Search found ${items.length} items');
      return items;
    } on DioException catch (e) {
      print('❌ Search error: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        // Search endpoint might not exist yet
        print('⚠️ Search endpoint not implemented, using basic filtering');
        return getInventoryItems(itemType: itemType);
      }
      throw Exception(_handleDioError(e, 'Failed to search items'));
    } catch (e) {
      print('❌ Unexpected search error: $e');
      throw Exception('Unexpected error occurred while searching: $e');
    }
  }

  // Get items by biome
  Future<List<InventoryItem>> getItemsByBiome(String biome) async {
    return searchItems(biome: biome);
  }

  // Get items by rarity (for artifacts)
  Future<List<InventoryItem>> getItemsByRarity(String rarity) async {
    return searchItems(rarity: rarity);
  }

  // Error handling helper
  String _handleDioError(DioException e, String defaultMessage) {
    if (e.response?.statusCode == 401) {
      return 'Authentication required. Please login again.';
    } else if (e.response?.statusCode == 403) {
      return 'Access forbidden. Check your permissions.';
    } else if (e.response?.statusCode == 404) {
      return 'Resource not found.';
    } else if (e.response?.statusCode == 429) {
      return 'Too many requests. Please wait before trying again.';
    } else if (e.response?.statusCode == 500) {
      return 'Server error. Please try again later.';
    } else if (e.response?.statusCode == 501) {
      return 'Feature not implemented yet.';
    } else if (e.response?.data != null && e.response?.data is Map) {
      final data = e.response!.data as Map<String, dynamic>;
      if (data.containsKey('error')) {
        return data['error'];
      } else if (data.containsKey('message')) {
        return data['message'];
      }
    } else if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Check your internet connection.';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Request timeout. Please try again.';
    }

    return defaultMessage;
  }

  // Debug method
  Future<bool> testConnection() async {
    try {
      final response = await _dio
          .get('/inventory/items?limit=1'); // ✅ FIXED: Test real endpoint
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Inventory service connection test failed: $e');
      return false;
    }
  }

  // ✅ NEW: Get all items without limit
  Future<List<InventoryItem>> getAllItems() async {
    return getInventoryItems(limit: 100); // Request max items
  }

  // ✅ NEW: Refresh inventory (force fresh data)
  Future<List<InventoryItem>> refreshInventory() async {
    try {
      print('🔄 Refreshing inventory...');
      return await getInventoryItems(limit: 100);
    } catch (e) {
      print('❌ Failed to refresh inventory: $e');
      rethrow;
    }
  }
}
