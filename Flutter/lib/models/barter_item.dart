import 'package:trade_match/models/user.dart';
import 'package:trade_match/models/category.dart';
import 'package:trade_match/models/item_image.dart';
import 'package:trade_match/models/item_want.dart';

class BarterItem {
  final int id;
  final String title;
  final String description;
  final String condition;
  final double? estimatedValue;
  final String currency;
  final String locationCity;
  final double locationLat;
  final double locationLon;
  final String wantsDescription;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt; // Nullable: Edge Function doesn't return this
  final User user;
  final Category?
  category; // Nullable: Edge Function may not include full category
  final List<ItemImage> images;
  final List<ItemWant> wants;

  BarterItem({
    required this.id,
    required this.title,
    required this.description,
    required this.condition,
    this.estimatedValue,
    required this.currency,
    required this.locationCity,
    required this.locationLat,
    required this.locationLon,
    required this.wantsDescription,
    required this.status,
    required this.createdAt,
    this.updatedAt, // Nullable
    required this.user,
    this.category, // Nullable
    required this.images,
    required this.wants,
  });

  factory BarterItem.fromJson(Map<String, dynamic> json) {
    return BarterItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      condition: json['condition'] ?? 'unknown',
      estimatedValue: json['estimated_value'] != null
          ? double.tryParse(json['estimated_value'].toString())
          : null,
      currency: json['currency'] ?? 'IDR',
      locationCity: json['location_city'] ?? 'Unknown',
      locationLat:
          double.tryParse((json['location_lat'] ?? 0).toString()) ?? 0.0,
      locationLon:
          double.tryParse((json['location_lon'] ?? 0).toString()) ?? 0.0,
      wantsDescription: json['wants_description'] ?? '',
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      user: User.fromJson(json['user'] ?? {'id': '0', 'name': 'Unknown'}),
      category: json['category'] != null
          ? Category.fromJson(json['category'])
          : null,
      images: (json['images'] as List<dynamic>? ?? [])
          .map((imageJson) => ItemImage.fromJson(imageJson))
          .toList(),
      wants: (json['wants'] as List<dynamic>? ?? [])
          .map((wantJson) => ItemWant.fromJson(wantJson))
          .toList(),
    );
  }
}

class BarterMatch {
  final int id;
  final int itemAId;
  final int itemBId;
  final String status;
  final bool itemAOwnerConfirmed;
  final bool itemBOwnerConfirmed;
  final BarterItem itemA;
  final BarterItem itemB;
  final ChatMessage? latestMessage;
  final DateTime updatedAt;

  BarterMatch({
    required this.id,
    required this.itemAId,
    required this.itemBId,
    required this.status,
    required this.itemAOwnerConfirmed,
    required this.itemBOwnerConfirmed,
    required this.itemA,
    required this.itemB,
    this.latestMessage,
    required this.updatedAt,
  });

  factory BarterMatch.fromJson(Map<String, dynamic> json) {
    // Handle both camelCase (from Supabase alias) and snake_case keys
    final itemAData = json['itemA'] ?? json['item_a'];
    final itemBData = json['itemB'] ?? json['item_b'];
    final latestMsgData = json['latestMessage'] ?? json['latest_message'];

    // latestMessage could be a list (from Supabase) or single object
    dynamic latestMessageJson;
    if (latestMsgData is List && latestMsgData.isNotEmpty) {
      latestMessageJson = latestMsgData.first;
    } else if (latestMsgData is Map) {
      latestMessageJson = latestMsgData;
    }

    return BarterMatch(
      id: int.tryParse(json['id'].toString()) ?? 0,
      itemAId: int.tryParse(json['item_a_id'].toString()) ?? 0,
      itemBId: int.tryParse(json['item_b_id'].toString()) ?? 0,
      status: json['status'] ?? 'active',
      itemAOwnerConfirmed:
          json['item_a_owner_confirmed'] == 1 ||
          json['item_a_owner_confirmed'] == true,
      itemBOwnerConfirmed:
          json['item_b_owner_confirmed'] == 1 ||
          json['item_b_owner_confirmed'] == true,
      itemA: BarterItem.fromJson(itemAData ?? {'id': 0, 'title': 'Unknown'}),
      itemB: BarterItem.fromJson(itemBData ?? {'id': 0, 'title': 'Unknown'}),
      latestMessage: latestMessageJson != null
          ? ChatMessage.fromJson(latestMessageJson)
          : null,
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

/// Simple model for chat message preview in swap list
class ChatMessage {
  final int id;
  final String messageText;
  final String type;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.messageText,
    required this.type,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: int.tryParse(json['id'].toString()) ?? 0,
      messageText: json['message_text'] ?? '',
      type: json['type'] ?? 'text',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
