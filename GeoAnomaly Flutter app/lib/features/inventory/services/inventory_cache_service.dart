import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inventory_item_model.dart';
import '../models/artifact_item_model.dart';
import '../models/gear_item_model.dart';
import '../models/inventory_summary_model.dart';

class InventoryCacheService {
  // Cache keys
  static const String _inventoryItemsKey = 'inventory_items_cache';
  static const String _artifactDetailsKey = 'artifact_details_cache';
  static const String _gearDetailsKey = 'gear_details_cache';
  static const String _inventorySummaryKey = 'inventory_summary_cache';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const String _lastUpdateKey = 'last_update';

  // Cache duration (1 hour)
  static const Duration _cacheValidDuration = Duration(hours: 1);

  // Cache inventory items for offline viewing
  Future<void> cacheInventoryItems(List<InventoryItem> items) async {
    try {
      print('💾 Caching ${items.length} inventory items...');

      final prefs = await SharedPreferences.getInstance();
      final jsonData = items.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(jsonData);

      await prefs.setString(_inventoryItemsKey, jsonString);
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);

      print('✅ Inventory items cached successfully');
    } catch (e) {
      print('❌ Failed to cache inventory items: $e');
    }
  }

  // Get cached inventory items
  Future<List<InventoryItem>?> getCachedInventoryItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_inventoryItemsKey);

      if (jsonString == null) {
        print('⚠️ No cached inventory items found');
        return null;
      }

      // Check cache validity
      if (!await _isCacheValid()) {
        print('⚠️ Cached inventory items are expired');
        await clearInventoryCache();
        return null;
      }

      final List<dynamic> jsonData = jsonDecode(jsonString);
      final items =
          jsonData.map((item) => InventoryItem.fromJson(item)).toList();

      print('✅ Loaded ${items.length} cached inventory items');
      return items;
    } catch (e) {
      print('❌ Failed to load cached inventory items: $e');
      return null;
    }
  }

  // Cache detailed artifact information
  Future<void> cacheArtifactDetails(
      String artifactId, ArtifactItem artifact) async {
    try {
      print('💾 Caching artifact details: ${artifact.name}');

      final prefs = await SharedPreferences.getInstance();
      final existingCache = await _getCachedArtifactDetails();

      existingCache[artifactId] = artifact.toJson();

      await prefs.setString(_artifactDetailsKey, jsonEncode(existingCache));
      await prefs.setInt('${_artifactDetailsKey}_timestamp',
          DateTime.now().millisecondsSinceEpoch);

      print('✅ Artifact details cached: ${artifact.name}');
    } catch (e) {
      print('❌ Failed to cache artifact details: $e');
    }
  }

  // Get cached artifact details
  Future<ArtifactItem?> getCachedArtifactDetails(String artifactId) async {
    try {
      final cachedData = await _getCachedArtifactDetails();

      if (!cachedData.containsKey(artifactId)) {
        print('⚠️ No cached artifact found: $artifactId');
        return null;
      }

      final artifact = ArtifactItem.fromJson(cachedData[artifactId]);
      print('✅ Loaded cached artifact: ${artifact.name}');
      return artifact;
    } catch (e) {
      print('❌ Failed to load cached artifact: $e');
      return null;
    }
  }

  // Cache detailed gear information
  Future<void> cacheGearDetails(String gearId, GearItem gear) async {
    try {
      print('💾 Caching gear details: ${gear.name}');

      final prefs = await SharedPreferences.getInstance();
      final existingCache = await _getCachedGearDetails();

      existingCache[gearId] = gear.toJson();

      await prefs.setString(_gearDetailsKey, jsonEncode(existingCache));
      await prefs.setInt('${_gearDetailsKey}_timestamp',
          DateTime.now().millisecondsSinceEpoch);

      print('✅ Gear details cached: ${gear.name}');
    } catch (e) {
      print('❌ Failed to cache gear details: $e');
    }
  }

  // Get cached gear details
  Future<GearItem?> getCachedGearDetails(String gearId) async {
    try {
      final cachedData = await _getCachedGearDetails();

      if (!cachedData.containsKey(gearId)) {
        print('⚠️ No cached gear found: $gearId');
        return null;
      }

      final gear = GearItem.fromJson(cachedData[gearId]);
      print('✅ Loaded cached gear: ${gear.name}');
      return gear;
    } catch (e) {
      print('❌ Failed to load cached gear: $e');
      return null;
    }
  }

  // Cache inventory summary
  Future<void> cacheInventorySummary(InventorySummary summary) async {
    try {
      print('💾 Caching inventory summary...');

      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(summary.toJson());

      await prefs.setString(_inventorySummaryKey, jsonString);
      await prefs.setInt('${_inventorySummaryKey}_timestamp',
          DateTime.now().millisecondsSinceEpoch);

      print('✅ Inventory summary cached');
    } catch (e) {
      print('❌ Failed to cache inventory summary: $e');
    }
  }

  // Get cached inventory summary
  Future<InventorySummary?> getCachedInventorySummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_inventorySummaryKey);

      if (jsonString == null) {
        print('⚠️ No cached inventory summary found');
        return null;
      }

      final summary = InventorySummary.fromJson(jsonDecode(jsonString));
      print('✅ Loaded cached inventory summary');
      return summary;
    } catch (e) {
      print('❌ Failed to load cached inventory summary: $e');
      return null;
    }
  }

  // Cache validation
  Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);

      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(cacheTime);

      final isValid = difference < _cacheValidDuration;

      if (!isValid) {
        print('⚠️ Cache expired. Age: ${difference.inMinutes} minutes');
      }

      return isValid;
    } catch (e) {
      print('❌ Failed to check cache validity: $e');
      return false;
    }
  }

  // Private helpers
  Future<Map<String, dynamic>> _getCachedArtifactDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_artifactDetailsKey);

      if (jsonString == null) return {};

      return Map<String, dynamic>.from(jsonDecode(jsonString));
    } catch (e) {
      print('❌ Failed to load artifact cache: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getCachedGearDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_gearDetailsKey);

      if (jsonString == null) return {};

      return Map<String, dynamic>.from(jsonDecode(jsonString));
    } catch (e) {
      print('❌ Failed to load gear cache: $e');
      return {};
    }
  }

  // Cache management
  Future<void> clearInventoryCache() async {
    try {
      print('🗑️ Clearing inventory cache...');

      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_inventoryItemsKey);
      await prefs.remove(_cacheTimestampKey);

      print('✅ Inventory cache cleared');
    } catch (e) {
      print('❌ Failed to clear inventory cache: $e');
    }
  }

  Future<void> clearDetailsCache() async {
    try {
      print('🗑️ Clearing details cache...');

      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_artifactDetailsKey);
      await prefs.remove(_gearDetailsKey);
      await prefs.remove('${_artifactDetailsKey}_timestamp');
      await prefs.remove('${_gearDetailsKey}_timestamp');

      print('✅ Details cache cleared');
    } catch (e) {
      print('❌ Failed to clear details cache: $e');
    }
  }

  Future<void> clearAllCache() async {
    try {
      print('🗑️ Clearing all inventory cache...');

      await clearInventoryCache();
      await clearDetailsCache();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_inventorySummaryKey);
      await prefs.remove('${_inventorySummaryKey}_timestamp');
      await prefs.remove(_lastUpdateKey);

      print('✅ All inventory cache cleared');
    } catch (e) {
      print('❌ Failed to clear all cache: $e');
    }
  }

  // Cache information
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      final isValid = await _isCacheValid();

      final cacheTime = timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null;

      final age =
          cacheTime != null ? DateTime.now().difference(cacheTime) : null;

      return {
        'has_cache': timestamp != null,
        'is_valid': isValid,
        'cache_time': cacheTime?.toIso8601String(),
        'age_minutes': age?.inMinutes,
        'size_estimate': _estimateCacheSize(),
      };
    } catch (e) {
      print('❌ Failed to get cache info: $e');
      return {};
    }
  }

  int _estimateCacheSize() {
    // Rough estimate - would need actual implementation
    return 0;
  }

  // Update tracking
  Future<void> updateLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ Failed to update last sync time: $e');
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastUpdateKey);

      if (timestamp == null) return null;

      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      print('❌ Failed to get last sync time: $e');
      return null;
    }
  }
}
