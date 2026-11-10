import 'package:hive/hive.dart';

part 'category.g.dart'; // Generated file

@HiveType(typeId: 1) // TypeId 1 for Category
class Category extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int? parentId;

  @HiveField(3)
  final String? iconUrl;

  @HiveField(4)
  final List<Category>? children;

  Category({
    required this.id,
    required this.name,
    this.parentId,
    this.iconUrl,
    this.children,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] != null ? int.parse(json['id'].toString()) : 0,
      name: json['name'] ?? 'Unknown Category',
      parentId: json['parent_id'] != null
          ? int.parse(json['parent_id'].toString())
          : null,
      iconUrl:
          json['icon_url'] ??
          json['icon'], // Edge Function returns 'icon', not 'icon_url'
      children: json['children'] != null
          ? (json['children'] as List)
                .map((category) => Category.fromJson(category))
                .toList()
          : null,
    );
  }
}
