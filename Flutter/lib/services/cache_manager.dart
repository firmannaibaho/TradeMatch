import 'package:trade_match/services/storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Utility class for cache management operations.
/// 
/// Provides cache cleanup, size calculation, and manual cache clearing.
class CacheManager {
  /// Remove all expired cache entries based on TTL
  static Future<void> cleanupExpiredData() async {
    try {
      final metadataBox = StorageService.metadataBox;
      if (metadataBox == null) {
        print('⚠️ MetadataBox not available for cleanup');
        return;
      }
      
      // Find expired entries
      final expiredKeys = <String>[];
      for (var key in metadataBox.keys) {
        final metadata = metadataBox.get(key);
        if (metadata != null && metadata.isExpired) {
          expiredKeys.add(key);
        }
      }
      
      // Remove expired metadata
      for (var key in expiredKeys) {
        await metadataBox.delete(key);
      }
      
      if (expiredKeys.isNotEmpty) {
        print('✅ Cleaned up ${expiredKeys.length} expired cache entries');
      }
    } catch (e) {
      print('⚠️ Error cleaning up expired data: $e');
    }
  }
  
  /// Clear all cached data (manual user action)
  static Future<void> clearAllCache() async {
    try {
      final categoriesBox = StorageService.categoriesBox;
      final metadataBox = StorageService.metadataBox;
      
      if (categoriesBox != null) {
        await categoriesBox.clear();
        print('✅ Cleared categories cache');
      }
      
      if (metadataBox != null) {
        await metadataBox.clear();
        print('✅ Cleared metadata cache');
      }
      
      print('✅ All cache cleared successfully');
    } catch (e) {
      print('⚠️ Error clearing cache: $e');
      rethrow; // Re-throw so UI can show error
    }
  }
  
  /// Calculate total cache size in bytes
  /// Returns human-readable string (e.g., "2.5 MB")
  static Future<String> getCacheSize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory(appDir.path);
      
      if (!await hiveDir.exists()) {
        return '0 KB';
      }
      
      int totalBytes = 0;
      
      // Calculate size of all files in Hive directory
      await for (var entity in hiveDir.list(recursive: true)) {
        if (entity is File) {
          try {
            totalBytes += await entity.length();
          } catch (e) {
            // Skip files we can't read
          }
        }
      }
      
      return _formatBytes(totalBytes);
    } catch (e) {
      print('⚠️ Error calculating cache size: $e');
      return 'Unknown';
    }
  }
  
  /// Format bytes into human-readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
