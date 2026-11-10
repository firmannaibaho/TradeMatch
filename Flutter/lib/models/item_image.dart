class ItemImage {
  final int id;
  final int itemId;
  final String imageUrl;
  final int sortOrder;

  ItemImage({
    required this.id,
    required this.itemId,
    required this.imageUrl,
    required this.sortOrder,
  });

  factory ItemImage.fromJson(Map<String, dynamic> json) {
    return ItemImage(
      id: json['id'] != null ? int.parse(json['id'].toString()) : 0,
      itemId: json['item_id'] != null
          ? int.parse(json['item_id'].toString())
          : 0,
      imageUrl: json['image_url'] ?? '',
      sortOrder: json['sort_order'] != null
          ? int.parse(json['sort_order'].toString())
          : 0,
    );
  }
}
