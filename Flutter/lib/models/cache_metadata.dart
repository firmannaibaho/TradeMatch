import 'package:hive/hive.dart';

part 'cache_metadata.g.dart';

/// Tracks cache freshness for intelligent data revalidation.
/// 
/// Used to determine if cached data is still valid or needs refresh.
@HiveType(typeId: 200) // High typeId (<= 223) to avoid conflicts with future models
class CacheMetadata extends HiveObject {
  @override
  @HiveField(0)
  final String key; // e.g., "user_items", "categories"
  
  @HiveField(1)
  final DateTime cachedAt;
  
  @HiveField(2)
  final int ttlSeconds; // Duration stored as seconds for Hive compatibility
  
  CacheMetadata({
    required this.key,
    required this.cachedAt,
    required this.ttlSeconds,
  });
  
  /// Check if cache is expired based on TTL
  bool get isExpired {
    final ttl = Duration(seconds: ttlSeconds);
    return DateTime.now().difference(cachedAt) > ttl;
  }
  
  /// Create metadata with Duration (converts to seconds internally)
  factory CacheMetadata.withDuration({
    required String key,
    required DateTime cachedAt,
    required Duration ttl,
  }) {
    return CacheMetadata(
      key: key,
      cachedAt: cachedAt,
      ttlSeconds: ttl.inSeconds,
    );
  }
}
