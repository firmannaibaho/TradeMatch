import 'package:hive/hive.dart';
import 'package:trade_match/models/cache_metadata.dart';
import 'package:trade_match/models/category.dart';

/// Central service for managing Hive storage boxes and type adapters.
/// 
/// CRITICAL: All methods wrapped in try-catch to ensure app continues
/// even if Hive operations fail (zero regression guarantee).
class StorageService {
  // Hive boxes - lazy initialized
  static Box<Category>? _categoriesBox;
  static Box<CacheMetadata>? _metadataBox;
  
  // Public getters with null safety
  static Box<Category>? get categoriesBox => _categoriesBox;
  static Box<CacheMetadata>? get metadataBox => _metadataBox;
  
  /// Initialize Hive storage - register adapters and open boxes.
  /// 
  /// Returns true if successful, false if failed (app continues either way).
  static Future<bool> init() async {
    try {
      // Register type adapters
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CategoryAdapter());
      }
      if (!Hive.isAdapterRegistered(200)) {
        Hive.registerAdapter(CacheMetadataAdapter());
      }
      
      // Open boxes
      _categoriesBox = await Hive.openBox<Category>('categories');
      _metadataBox = await Hive.openBox<CacheMetadata>('metadata');
      
      print('✅ StorageService initialized successfully');
      print('   Categories box: ${_categoriesBox!.length} items');
      print('   Metadata box: ${_metadataBox!.length} items');
      
      return true;
    } catch (e) {
      print('⚠️ StorageService initialization failed: $e');
      print('   App will continue without caching');
      return false;
    }
  }
  
  /// Close all Hive boxes (cleanup on app exit)
  static Future<void> close() async {
    try {
      await _categoriesBox?.close();
      await _metadataBox?.close();
      print('✅ StorageService boxes closed');
    } catch (e) {
      print('⚠️ Error closing StorageService boxes: $e');
    }
  }
  
  /// Get cache metadata for a specific key
  static CacheMetadata? getCacheMetadata(String key) {
    try {
      return _metadataBox?.get(key);
    } catch (e) {
      print('⚠️ Error getting cache metadata for $key: $e');
      return null;
    }
  }
  
  /// Save cache metadata for a key
  static Future<void> saveCacheMetadata(String key, Duration ttl) async {
    try {
      final metadata = CacheMetadata.withDuration(
        key: key,
        cachedAt: DateTime.now(),
        ttl: ttl,
      );
      await _metadataBox?.put(key, metadata);
    } catch (e) {
      print('⚠️ Error saving cache metadata for $key: $e');
    }
  }
}
