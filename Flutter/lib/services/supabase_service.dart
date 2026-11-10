// Flutter Supabase Service
// Replaces ApiService with Supabase SDK calls
// Path: lib/services/supabase_service.dart

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => client.auth.currentUser;
  String? get userId => currentUser?.id;

  // ==========================================
  // AUTHENTICATION
  // ==========================================

  /// Sign up with email and password
  /// Creates auth user AND inserts profile row in users table
  Future<AuthResponse> signUpWithEmail(
    String email,
    String password,
    String name, {
    String? phone,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );

    // Create user profile in public.users table
    // This is required because Supabase Auth only creates auth.users row
    if (response.user != null) {
      try {
        await client.from('users').upsert({
          'id': response.user!.id,
          'name': name,
          'email': email,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('✅ User profile created in users table');
      } catch (e) {
        print('⚠️ Failed to create user profile: $e');
        // Don't throw - auth was successful, profile creation can be retried
      }
    }

    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  /// Sign in with Google OAuth
  Future<AuthResponse> signInWithGoogle() async {
    final response = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.barterswap://login-callback/',
    );
    // Note: This returns immediately, actual auth happens via deep link
    throw UnimplementedError('Use signInWithIdToken for mobile Google sign-in');
  }

  /// Sign in with Google ID Token (for mobile)
  Future<AuthResponse> signInWithGoogleIdToken(
    String idToken,
    String? accessToken,
  ) async {
    final response = await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    return response;
  }

  /// Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ==========================================
  // USER PROFILE
  // ==========================================

  /// Get current user profile
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    if (userId == null) return null;
    final response = await client
        .from('users')
        .select()
        .eq('id', userId!)
        .single();
    return response;
  }

  /// Update user profile
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? defaultLocationCity,
    double? defaultLat,
    double? defaultLon,
  }) async {
    if (userId == null) throw Exception('Not authenticated');

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (defaultLocationCity != null)
      updates['default_location_city'] = defaultLocationCity;
    if (defaultLat != null) updates['default_lat'] = defaultLat;
    if (defaultLon != null) updates['default_lon'] = defaultLon;

    await client.from('users').update(updates).eq('id', userId!);
  }

  /// Upload profile picture
  Future<String> uploadProfilePicture(File file) async {
    if (userId == null) throw Exception('Not authenticated');

    final fileName =
        '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await client.storage.from('profile-pictures').upload(fileName, file);

    final url = client.storage.from('profile-pictures').getPublicUrl(fileName);

    await client
        .from('users')
        .update({'profile_picture_url': url})
        .eq('id', userId!);

    return url;
  }

  /// Upload background picture
  Future<String> uploadBackgroundPicture(File file) async {
    if (userId == null) throw Exception('Not authenticated');

    final fileName =
        '$userId/background_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await client.storage.from('profile-pictures').upload(fileName, file);

    final url = client.storage.from('profile-pictures').getPublicUrl(fileName);

    await client
        .from('users')
        .update({'background_picture_url': url})
        .eq('id', userId!);

    return url;
  }

  // ==========================================
  // CATEGORIES
  // ==========================================

  /// Get all categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await client.from('categories').select().order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  // ==========================================
  // ITEMS (CRUD via SDK)
  // ==========================================

  /// Get current user's items
  Future<List<Map<String, dynamic>>> getUserItems() async {
    if (userId == null) return [];
    final response = await client
        .from('items')
        .select('*, category:categories(*), images:item_images(*)')
        .eq('user_id', userId!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get a single item
  Future<Map<String, dynamic>?> getItem(int itemId) async {
    final response = await client
        .from('items')
        .select(
          '*, category:categories(*), images:item_images(*), user:users(id, name, profile_picture_url, rating, created_at)',
        )
        .eq('id', itemId)
        .single();
    return response;
  }

  /// Create a new item
  Future<Map<String, dynamic>> createItem({
    required String title,
    required String description,
    required int categoryId,
    required String condition,
    double? estimatedValue,
    String? locationCity,
    double? locationLat,
    double? locationLon,
    String? wantsDescription,
    List<int>? wantedCategoryIds,
    List<String>? imageUrls,
  }) async {
    if (userId == null) throw Exception('Not authenticated');

    final response = await client
        .from('items')
        .insert({
          'user_id': userId,
          'title': title,
          'description': description,
          'category_id': categoryId,
          'condition': condition,
          'estimated_value': estimatedValue,
          'location_city': locationCity,
          'location_lat': locationLat,
          'location_lon': locationLon,
          'wants_description': wantsDescription,
        })
        .select()
        .single();

    // Add wanted categories
    if (wantedCategoryIds != null && wantedCategoryIds.isNotEmpty) {
      await client
          .from('item_wants')
          .insert(
            wantedCategoryIds
                .map(
                  (catId) => {'item_id': response['id'], 'category_id': catId},
                )
                .toList(),
          );
    }

    // Add images to item_images table
    if (imageUrls != null && imageUrls.isNotEmpty) {
      final imageInserts = imageUrls.asMap().entries.map((entry) {
        return {
          'item_id': response['id'],
          'image_url': entry.value,
          'display_order': entry.key,
        };
      }).toList();

      print('📸 Inserting ${imageInserts.length} images to item_images table');
      await client.from('item_images').insert(imageInserts);
      print('✅ Images linked to item successfully');
    }

    return response;
  }

  /// Update an item
  Future<void> updateItem(int itemId, Map<String, dynamic> updates) async {
    await client.from('items').update(updates).eq('id', itemId);
  }

  /// Delete an item (hard delete from database)
  Future<void> deleteItem(int itemId) async {
    if (userId == null) throw Exception('Not authenticated');

    try {
      print('🗑️ Attempting to delete item $itemId for user $userId');

      // Check if item is in any active swap
      final activeSwaps = await client
          .from('swaps')
          .select('id, status')
          .or('item_a_id.eq.$itemId,item_b_id.eq.$itemId')
          .inFilter('status', [
            'active',
            'location_suggested',
            'location_agreed',
          ]);

      if ((activeSwaps as List).isNotEmpty) {
        throw Exception('Cannot delete item that is in an active trade');
      }

      // Delete related swipes where this item was the swiper or swiped on
      await client.from('swipes').delete().eq('swiper_item_id', itemId);

      await client.from('swipes').delete().eq('swiped_on_item_id', itemId);

      // Delete related records (images, wants)
      await client.from('item_images').delete().eq('item_id', itemId);

      await client.from('item_wants').delete().eq('item_id', itemId);

      // Then delete the item itself
      await client
          .from('items')
          .delete()
          .eq('id', itemId)
          .eq('user_id', userId!);

      print('✅ Item $itemId deleted successfully from database');
    } catch (e) {
      print('❌ Error deleting item $itemId: $e');
      rethrow;
    }
  }

  /// Upload item image
  Future<String> uploadItemImage(
    int itemId,
    File file,
    int displayOrder,
  ) async {
    final fileName = '$itemId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await client.storage.from('item-images').upload(fileName, file);

    final url = client.storage.from('item-images').getPublicUrl(fileName);

    await client.from('item_images').insert({
      'item_id': itemId,
      'image_url': url,
      'display_order': displayOrder,
    });

    return url;
  }

  // ==========================================
  // EXPLORE (via Edge Function)
  // ==========================================

  /// Get explore feed
  Future<List<Map<String, dynamic>>> getExploreFeed({
    int? categoryId,
    int limit = 20,
  }) async {
    try {
      final response = await client.functions
          .invoke(
            'get-explore-feed',
            body: {
              if (categoryId != null) 'category_id': categoryId,
              'limit': limit,
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout: Edge function did not respond');
            },
          );

      if (response.status != 200) {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch explore feed',
        );
      }

      return List<Map<String, dynamic>>.from(response.data['items'] ?? []);
    } catch (e) {
      print('Error in getExploreFeed: $e');
      // Return empty list instead of throwing to prevent app crash
      return [];
    }
  }

  /// Get items the user has liked (for matches page)
  Future<List<Map<String, dynamic>>> getLikes() async {
    if (userId == null) return [];

    // Get all items the user has swiped "like" on
    final response = await client
        .from('swipes')
        .select('''
          *,
          swiped_on_item:items!swiped_on_item_id(
            *,
            category:categories(*),
            images:item_images(*),
            user:users(id, name, profile_picture_url, rating)
          )
        ''')
        .eq('swiper_user_id', userId!)
        .eq('action', 'like')
        .order('created_at', ascending: false);

    // Extract just the items
    final items = (response as List)
        .map((swipe) => swipe['swiped_on_item'])
        .toList();
    return List<Map<String, dynamic>>.from(items);
  }

  /// Upload a generic image (for item images)
  Future<String> uploadImage(File imageFile) async {
    if (userId == null) throw Exception('Not authenticated');

    final fileName = '${userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await client.storage.from('item-images').upload(fileName, imageFile);

    final url = client.storage.from('item-images').getPublicUrl(fileName);
    return url;
  }

  // ==========================================
  // SWIPE (via Edge Function)
  // ==========================================

  /// Process a swipe action
  Future<Map<String, dynamic>> swipe(
    int swiperItemId,
    int swipedOnItemId,
    String action,
  ) async {
    final response = await client.functions.invoke(
      'process-swipe',
      body: {
        'swiper_item_id': swiperItemId,
        'swiped_on_item_id': swipedOnItemId,
        'action': action,
      },
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Swipe failed');
    }

    return response.data;
  }

  // ==========================================
  // SWAPS (via SDK + Edge Functions)
  // ==========================================

  /// Get user's swaps
  Future<List<Map<String, dynamic>>> getSwaps({String? status}) async {
    if (userId == null) return [];

    var query = client.from('swaps').select('''
          *,
          item_a_snapshot,
          item_b_snapshot,
          itemA:items!item_a_id(*, images:item_images(*), user:users(id, name, profile_picture_url)),
          itemB:items!item_b_id(*, images:item_images(*), user:users(id, name, profile_picture_url)),
          latestMessage:messages(id, message_text, created_at, sender_user_id)
        ''');

    if (status != null) {
      query = query.eq('status', status);
    } else {
      query = query.or('user_a_id.eq.$userId,user_b_id.eq.$userId');
    }

    final response = await query.order('updated_at', ascending: false);

    // Patch items from snapshots if relational data is missing (e.g. deleted items)
    final List<Map<String, dynamic>> swaps = List<Map<String, dynamic>>.from(
      response,
    );
    for (var swap in swaps) {
      if (swap['itemA'] == null && swap['item_a_snapshot'] != null) {
        swap['itemA'] = swap['item_a_snapshot'];
      }
      if (swap['itemB'] == null && swap['item_b_snapshot'] != null) {
        swap['itemB'] = swap['item_b_snapshot'];
      }
    }

    return swaps;
  }

  /// Get completed trades (for trade history in profile)
  /// Uses item snapshots since items are deleted after trade completion
  Future<List<Map<String, dynamic>>> getCompletedTrades() async {
    if (userId == null) return [];

    final response = await client
        .from('swaps')
        .select('''
          *,
          item_a_snapshot,
          item_b_snapshot,
          itemA:items!item_a_id(*, images:item_images(*), user:users(id, name, profile_picture_url)),
          itemB:items!item_b_id(*, images:item_images(*), user:users(id, name, profile_picture_url))
        ''')
        .eq('status', 'trade_complete')
        .or('user_a_id.eq.$userId,user_b_id.eq.$userId')
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get a single swap by ID
  Future<Map<String, dynamic>> getSwap(int swapId) async {
    final response = await client
        .from('swaps')
        .select('''
          *,
          item_a:items!swaps_item_a_id_fkey(
            *,
            user:users(*),
            category:categories(*),
            images:item_images(*),
            wants:item_wants(*, category:categories(*))
          ),
          item_b:items!swaps_item_b_id_fkey(
            *,
            user:users(*),
            category:categories(*),
            images:item_images(*),
            wants:item_wants(*, category:categories(*))
          )
        ''')
        .eq('id', swapId)
        .single();
    return response as Map<String, dynamic>;
  }

  /// Get messages for a swap
  Future<List<Map<String, dynamic>>> getMessages(int swapId) async {
    final response = await client
        .from('messages')
        .select('*, sender:users(id, name, profile_picture_url)')
        .eq('swap_id', swapId)
        .order('created_at', ascending: true); // Oldest first, newest last
    return List<Map<String, dynamic>>.from(response);
  }

  /// Send a message
  Future<Map<String, dynamic>> sendMessage(
    int swapId,
    String messageText, {
    String type = 'text',
    double? locationLat,
    double? locationLon,
    String? locationName,
    String? locationAddress,
  }) async {
    if (userId == null) throw Exception('Not authenticated');

    // Only insert basic fields that exist in the database
    // type and location fields are accepted but not stored until DB is updated
    final response = await client
        .from('messages')
        .insert({
          'swap_id': swapId,
          'sender_user_id': userId,
          'message_text': messageText,
          'type': type,
          if (locationLat != null) 'location_lat': locationLat,
          if (locationLon != null) 'location_lon': locationLon,
          if (locationName != null) 'location_name': locationName,
          if (locationAddress != null) 'location_address': locationAddress,
        })
        .select('*, sender:users(id, name)')
        .single();

    return response;
  }

  /// Mark messages as read for a swap (messages not sent by current user)
  Future<void> markMessagesAsRead(int swapId) async {
    if (userId == null) return;

    try {
      print('📖 Marking messages as read for swap $swapId');
      await client
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('swap_id', swapId)
          .neq('sender_user_id', userId!);
      print('✅ Messages marked as read for swap $swapId');
    } catch (e) {
      print('❌ Error marking messages as read: $e');
      // Don't rethrow - this is not critical functionality
    }
  }

  /// Get unread message count for a swap
  Future<int> getUnreadMessageCount(int swapId) async {
    if (userId == null) return 0;

    try {
      final response = await client
          .from('messages')
          .select('id, read_at')
          .eq('swap_id', swapId)
          .neq('sender_user_id', userId!);

      final unreadMessages = (response as List)
          .where((msg) => msg['read_at'] == null)
          .toList();
      print('📬 Swap $swapId: ${unreadMessages.length} unread messages');
      return unreadMessages.length;
    } catch (e) {
      print('❌ Error getting unread count for swap $swapId: $e');
      return 0;
    }
  }

  /// Get total unread messages for all swaps
  Future<int> getTotalUnreadCount() async {
    if (userId == null) return 0;

    // Get all swaps user is part of
    final swaps = await getSwaps();
    int totalUnread = 0;

    for (final swap in swaps) {
      final swapId = swap['id'] as int?;
      if (swapId != null) {
        totalUnread += await getUnreadMessageCount(swapId);
      }
    }

    return totalUnread;
  }

  /// Confirm a trade
  Future<Map<String, dynamic>> confirmTrade(int swapId) async {
    final response = await client.functions.invoke(
      'confirm-trade',
      body: {'swap_id': swapId},
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Failed to confirm trade');
    }

    return response.data;
  }

  /// Cancel a trade
  Future<void> cancelTrade(int swapId) async {
    if (userId == null) throw Exception('Not authenticated');

    await client
        .from('swaps')
        .update({'status': 'cancelled'})
        .eq('id', swapId)
        .eq('status', 'active'); // Only allow cancelling active trades
  }

  /// Suggest a meeting location (and optional meetup date/time)
  Future<Map<String, dynamic>> suggestLocation(
    int swapId,
    double lat,
    double lon, {
    String? name,
    String? address,
    DateTime? meetupAt,
    String? meetupLabel,
  }) async {
    final response = await client.functions.invoke(
      'suggest-location',
      body: {
        'swap_id': swapId,
        'location_lat': lat,
        'location_lon': lon,
        'location_name': name,
        'location_address': address,
        if (meetupAt != null) 'meetup_at': meetupAt.toUtc().toIso8601String(),
        if (meetupLabel != null) 'meetup_label': meetupLabel,
      },
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Failed to suggest location');
    }

    return response.data;
  }

  /// Accept a suggested location
  Future<Map<String, dynamic>> acceptLocation(int swapId) async {
    final response = await client.functions.invoke(
      'accept-location',
      body: {'swap_id': swapId},
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Failed to accept location');
    }

    return response.data;
  }

  // ==========================================
  // REVIEWS (via Edge Function)
  // ==========================================

  /// Get reviews for a user
  Future<List<Map<String, dynamic>>> getUserReviews(String userId) async {
    final response = await client
        .from('reviews')
        .select(
          '*, reviewer:users!reviewer_user_id(id, name, profile_picture_url), swap:swaps(id)',
        )
        .eq('reviewed_user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Create a review
  Future<Map<String, dynamic>> createReview(
    int swapId,
    int rating, {
    String? comment,
  }) async {
    final response = await client.functions.invoke(
      'create-review',
      body: {'swap_id': swapId, 'rating': rating, 'comment': comment},
    );

    if (response.status != 200 && response.status != 201) {
      throw Exception(response.data['error'] ?? 'Failed to create review');
    }

    return response.data;
  }

  // ==========================================
  // NOTIFICATIONS (via SDK)
  // ==========================================

  /// Get user's notifications
  Future<List<Map<String, dynamic>>> getNotifications() async {
    if (userId == null) return [];

    final response = await client
        .from('notifications')
        .select()
        .eq('user_id', userId!)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    if (userId == null) return;
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId!)
        .eq('is_read', false);
  }

  /// Get unread notifications count as a stream
  /// This will automatically update when notifications change
  Stream<int> getUnreadNotificationsCount() {
    if (userId == null) {
      return Stream.value(0);
    }

    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .map(
          (notifications) => notifications
              .where((n) => n['user_id'] == userId && n['is_read'] == false)
              .length,
        );
  }

  /// Get unread messages count as a stream
  Stream<int> getUnreadMessagesCount() {
    if (userId == null) {
      return Stream.value(0);
    }

    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .map(
          (messages) => messages
              .where(
                (m) => m['sender_user_id'] != userId && m['read_at'] == null,
              )
              .length,
        );
  }

  // ==========================================
  // REALTIME SUBSCRIPTIONS
  // ==========================================

  /// Subscribe to messages for a swap
  RealtimeChannel subscribeToMessages(
    int swapId,
    void Function(Map<String, dynamic>) onMessage,
  ) {
    return client
        .channel('messages:swap:$swapId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'swap_id',
            value: swapId,
          ),
          callback: (payload) {
            onMessage(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Subscribe to swap updates
  RealtimeChannel subscribeToSwapUpdates(
    int swapId,
    void Function(Map<String, dynamic>) onUpdate,
  ) {
    return client
        .channel('swaps:$swapId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'swaps',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: swapId,
          ),
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Subscribe to notifications
  RealtimeChannel subscribeToNotifications(
    void Function(Map<String, dynamic>) onNotification,
  ) {
    if (userId == null) throw Exception('Not authenticated');

    return client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId!,
          ),
          callback: (payload) {
            onNotification(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Unsubscribe from a channel
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }
}
