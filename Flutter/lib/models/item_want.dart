import 'package:trade_match/models/category.dart';

class ItemWant {
  final int id;
  final int itemId;
  final int categoryId; // Changed from wantedCategoryId to match database
  final Category? category;

  ItemWant({
    required this.id,
    required this.itemId,
    required this.categoryId,
    this.category,
  });

  factory ItemWant.fromJson(Map<String, dynamic> json) {
    return ItemWant(
      id: json['id'] != null ? int.parse(json['id'].toString()) : 0,
      itemId: json['item_id'] != null
          ? int.parse(json['item_id'].toString())
          : 0,
      categoryId: json['category_id'] != null
          ? int.parse(json['category_id'].toString())
          : 0,
      category: json['category'] != null
          ? Category.fromJson(json['category'])
          : null,
    );
  }
}
