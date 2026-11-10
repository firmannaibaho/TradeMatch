import 'package:trade_match/models/category.dart';
import 'package:trade_match/models/item_image.dart';
import 'package:trade_match/models/item_want.dart';

class Item {
  final int id;
  final String userId; // Changed from int to String for Supabase UUID
  final int categoryId;
  final String title;
  final String description;
  final String condition;
  final double? estimatedValue;
  final String currency;
  final String locationCity;
  final double locationLat;
  final double locationLon;
  final String? wantsDescription;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Category? category;
  final List<ItemImage>? images;
  final List<ItemWant>? wants;

  Item({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.condition,
    this.estimatedValue,
    required this.currency,
    required this.locationCity,
    required this.locationLat,
    required this.locationLon,
    this.wantsDescription,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.images,
    this.wants,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: int.parse(json['id'].toString()),
      userId: json['user_id'].toString(), // Now accepts UUID string
      categoryId: int.parse(json['category_id'].toString()),
      title: json['title'],
      description: json['description'],
      condition: json['condition'],
      estimatedValue: json['estimated_value'] != null ? double.parse(json['estimated_value'].toString()) : null,
      currency: json['currency'] ?? 'USD',
      locationCity: json['location_city'] ?? '',
      locationLat: double.parse((json['location_lat'] ?? 0).toString()),
      locationLon: double.parse((json['location_lon'] ?? 0).toString()),
      wantsDescription: json['wants_description'],
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      category: json['category'] != null
          ? Category.fromJson(json['category'])
          : null,
      images: json['images'] != null
          ? (json['images'] as List)
              .map((image) => ItemImage.fromJson(image))
              .toList()
          : null,
      wants: json['wants'] != null
          ? (json['wants'] as List)
              .map((want) => ItemWant.fromJson(want))
              .toList()
          : null,
    );
  }
}

