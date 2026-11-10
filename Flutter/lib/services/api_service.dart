import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trade_match/models/item.dart';
import 'package:trade_match/models/category.dart';
import 'package:trade_match/models/barter_item.dart' hide Category;
import 'package:trade_match/services/storage_service.dart'; // Phase 2: Cache access
import 'constants.dart';

class ApiService {
  Future<List<BarterMatch>> getSwaps({String? status}) async {
    final uri = status != null
        ? Uri.parse('$API_BASE/api/swaps?status=$status')
        : Uri.parse('$API_BASE/api/swaps');
    
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body)['swaps'];
      List<BarterMatch> swaps = body.map((dynamic item) => BarterMatch.fromJson(item)).toList();
      return swaps;
    } else {
      throw Exception('Failed to load swaps');
    }
  }

  Future<List<BarterItem>> getExploreItems() async {
    final response = await http.get(
      Uri.parse('$API_BASE/api/explore'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final body = jsonResponse['items'];
      if (body == null) {
        print('Warning: items field is null in explore response');
        return []; // Return empty list instead of crashing
      }
      return body.map((dynamic item) => BarterItem.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load explore items');
    }
  }

  Future<List<BarterItem>> getLikes() async {
    // Assuming an endpoint for likes exists or using a placeholder
    // If no endpoint, we might return empty or mock
    // For now, let's assume GET /api/likes exists
    final response = await http.get(
      Uri.parse('$API_BASE/api/likes'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body)['likes'];
      return body.map((dynamic item) => BarterItem.fromJson(item)).toList();
    } else {
      // Fallback to empty list if endpoint doesn't exist yet
      return []; 
    }
  }

  /// Get all categories with intelligent caching (30 day TTL)
  /// 
  /// CHECKPOINT 4: Cache-first strategy with API fallback
  /// - Check cache first (fast!)
  /// - If cache valid → return instantly
  /// - If cache expired/missing → fetch from API, update cache
  /// - If Hive fails → gracefully fall back to API only
  Future<List<Category>> getCategories() async {
    const cacheKey = 'categories';
    const cacheTTL = Duration(days: 30); // Categories rarely change
    
    try {
      // STEP 1: Check if StorageService is available
      final categoriesBox = StorageService.categoriesBox;
      final metadataBox = StorageService.metadataBox;
      
      if (categoriesBox != null && metadataBox != null) {
        // STEP 2: Check cache metadata
        final metadata = metadataBox.get(cacheKey);
        
        // STEP 3: If cache is valid, return cached data (FAST PATH)
        if (metadata != null && !metadata.isExpired) {
          final cachedCategories = categoriesBox.values.toList();
          if (cachedCategories.isNotEmpty) {
            print('✅ Categories loaded from cache (${cachedCategories.length} items)');
            return cachedCategories;
          }
        }
        
        // STEP 4: Cache expired/empty - fetch from API
        print('⏳ Cache expired/empty, fetching categories from API...');
      } else {
        print('⚠️ StorageService not initialized, fetching from API');
      }
    } catch (e) {
      // Hive operation failed - gracefully fall back to API
      print('⚠️ Cache read error: $e - falling back to API');
    }
    
    // STEP 5: Fetch from API (either cache expired or Hive failed)
    final response = await http.get(
      Uri.parse('$API_BASE/api/categories'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final body = jsonResponse['categories'];
      if (body == null) {
        print('Warning: categories field is null in categories response');
        return []; // Return empty list instead of crashing
      }
      List<Category> categories = body.map((dynamic item) => Category.fromJson(item)).toList();
      
      // STEP 6: Update cache (best-effort - doesn't fail if Hive unavailable)
      try {
        final categoriesBox = StorageService.categoriesBox;
        if (categoriesBox != null) {
          await categoriesBox.clear();
          await categoriesBox.addAll(categories);
          await StorageService.saveCacheMetadata(cacheKey, cacheTTL);
          print('✅ Categories cached successfully (${categories.length} items)');
        }
      } catch (e) {
        print('⚠️ Failed to update cache: $e (continuing without caching)');
        // Don't throw - cache update is optional
      }
      
      return categories;
    } else {
      throw Exception('Failed to load categories');
    }
  }

  /// Confirm trade completion
  Future<Map<String, dynamic>> confirmTrade(int swapId) async {
    final response = await http.post(
      Uri.parse('$API_BASE/api/swaps/$swapId/confirm'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to confirm trade');
    }
  }

  Future<String> uploadImage(File imageFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$API_BASE/api/upload/image'),
    );
    request.headers['Authorization'] = 'Bearer $AUTH_TOKEN';
    request.headers['Accept'] = 'application/json';
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      var responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody)['url'];
    } else {
      throw Exception('Failed to upload image');
    }
  }

  Future<Item> createItem(Map<String, dynamic> itemData) async {
    final response = await http.post(
      Uri.parse('$API_BASE/api/items'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(itemData),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      final jsonResponse = jsonDecode(response.body);
      final itemData = jsonResponse['item'];
      if (itemData == null) {
        throw Exception('Item creation failed: no item data in response');
      }
      return Item.fromJson(itemData);
    } else {
      throw Exception('Failed to create item');
    }
  }

  Future<Item> updateItem(int id, Map<String, dynamic> itemData) async {
    final response = await http.put(
      Uri.parse('$API_BASE/api/items/\$id'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(itemData),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return Item.fromJson(jsonDecode(response.body)['item']);
    } else {
      throw Exception('Failed to update item: \${response.body}');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$API_BASE/api/login'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to login');
    }
  }

  Future<List<Item>> getUserItems() async {
    final response = await http.get(
      Uri.parse('$API_BASE/api/items'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final body = jsonResponse['items'];
      if (body == null) {
        print('Warning: items field is null in user items response');
        return []; // Return empty list instead of crashing
      }
      return body.map((dynamic item) => Item.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load items');
    }
  }

  Future<void> deleteItem(int id) async {
    final response = await http.delete(
      Uri.parse('$API_BASE/api/items/\$id'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete item');
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String phone, String password) async {
    print('Attempting to register user: $email');
    try {
      final response = await http.post(
        Uri.parse('$API_BASE/api/register'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'password_confirmation': password
        }),
      ).timeout(const Duration(seconds: 60));  // Tingkatkan timeout ke 60 detik

      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body}');

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to register: ${response.body}');
      }
    } catch (e) {
      print('Register error: $e');
      rethrow;
    }
  }

  Future<void> swipe(int swiperItemId, int swipedOnItemId, String action) async {
    final response = await http.post(
      Uri.parse('$API_BASE/api/swipe'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'swiper_item_id': swiperItemId,
        'swiped_on_item_id': swipedOnItemId,
        'action': action,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to swipe');
    }
  }
  final _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
    AUTH_TOKEN = token;
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      AUTH_TOKEN = token;
    }
    return token;
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
    AUTH_TOKEN = '';
  }

  Future<Map<String, dynamic>> getUser() async {
    final response = await http.get(
      Uri.parse('$API_BASE/api/user'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get user');
    }
  }

  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    print('Attempting Google Login with token: ${idToken.substring(0, 10)}...');
    try {
      final response = await http.post(
        Uri.parse('$API_BASE/api/auth/google'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({'id_token': idToken}),
      ).timeout(const Duration(seconds: 10));

      print('Google Login response status: ${response.statusCode}');
      print('Google Login response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to login with Google: ${response.body}');
      }
    } catch (e) {
      print('Google Login error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> googleRegister(String idToken) async {
    print('Attempting Google Registration with token: ${idToken.substring(0, 10)}...');
    try {
      final response = await http.post(
        Uri.parse('$API_BASE/api/auth/google/register'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({'id_token': idToken}),
      ).timeout(const Duration(seconds: 10));

      print('Google Register response status: ${response.statusCode}');
      print('Google Register response body: ${response.body}');

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 409) {
        throw Exception('User already exists. Please login instead.');
      } else {
        throw Exception('Failed to register with Google: ${response.body}');
      }
    } catch (e) {
      print('Google Register error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$API_BASE/api/logout'),
        headers: {
          'Authorization': 'Bearer $AUTH_TOKEN',
          'Accept': 'application/json',
        },
      );
    } catch (e) {
      // Ignore errors on logout
    }
    await deleteToken();
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$API_BASE/api/user/profile'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update profile');
    }
  }

  Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$API_BASE/api/user/profile-picture'),
    );
    request.headers['Authorization'] = 'Bearer $AUTH_TOKEN';
    request.headers['Accept'] = 'application/json';
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      var responseBody = await response.stream.bytesToString();
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to upload profile picture');
    }
  }

  // ===== REVIEWS API (Stage 6) =====

  /// Get reviews for a specific user with statistics
  Future<Map<String, dynamic>> getUserReviews(int userId, {int page = 1}) async {
    final response = await http.get(
      Uri.parse('$API_BASE/api/user/$userId/reviews?page=$page'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load reviews');
    }
  }

  /// Submit a new review
  Future<Map<String, dynamic>> createReview(Map<String, dynamic> reviewData) async {
    final response = await http.post(
      Uri.parse('$API_BASE/api/reviews'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(reviewData),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create review: ${response.body}');
    }
  }

  // ===== NOTIFICATIONS API (Stage 6) =====

  /// Get notifications for authenticated user
  Future<Map<String, dynamic>> getNotifications({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$API_BASE/api/notifications?page=$page'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  /// Mark a notification as read
  Future<void> markNotificationAsRead(int notificationId) async {
    final response = await http.put(
      Uri.parse('$API_BASE/api/notifications/$notificationId/mark-read'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    final response = await http.post(
      Uri.parse('$API_BASE/api/notifications/mark-all-read'),
      headers: {
        'Authorization': 'Bearer $AUTH_TOKEN',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to mark all notifications as read');
    }
  }
}
