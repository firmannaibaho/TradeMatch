class Review {
  final int id;
  final int swapId;
  final int reviewerUserId;
  final int reviewedUserId;
  final int rating;
  final String? comment;
  final List<String>? photos;
  final DateTime createdAt;

  // Nested objects from eager loading
  final ReviewerUser reviewer;
  final SwapSummary swap;

  Review({
    required this.id,
    required this.swapId,
    required this.reviewerUserId,
    required this.reviewedUserId,
    required this.rating,
    this.comment,
    this.photos,
    required this.createdAt,
    required this.reviewer,
    required this.swap,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      swapId: json['swap_id'],
      reviewerUserId: json['reviewer_user_id'],
      reviewedUserId: json['reviewed_user_id'],
      rating: json['rating'],
      comment: json['comment'],
      photos: json['photos'] != null ? List<String>.from(json['photos']) : null,
      createdAt: DateTime.parse(json['created_at']),
      reviewer: ReviewerUser.fromJson(json['reviewer']),
      swap: SwapSummary.fromJson(json['swap']),
    );
  }
}

class ReviewerUser {
  final int id;
  final String name;
  final String? profilePictureUrl;

  ReviewerUser({
    required this.id,
    required this.name,
    this.profilePictureUrl,
  });

  factory ReviewerUser.fromJson(Map<String, dynamic> json) {
    return ReviewerUser(
      id: json['id'],
      name: json['name'],
      profilePictureUrl: json['profile_picture_url'],
    );
  }
}

class SwapSummary {
  final int id;
  final ItemSummary itemA;
  final ItemSummary itemB;

  SwapSummary({
    required this.id,
    required this.itemA,
    required this.itemB,
  });

  factory SwapSummary.fromJson(Map<String, dynamic> json) {
    return SwapSummary(
      id: json['id'],
      itemA: ItemSummary.fromJson(json['item_a']),
      itemB: ItemSummary.fromJson(json['item_b']),
    );
  }
}

class ItemSummary {
  final int id;
  final String name;
  final String? primaryImageUrl;

  ItemSummary({
    required this.id,
    required this.name,
    this.primaryImageUrl,
  });

  factory ItemSummary.fromJson(Map<String, dynamic> json) {
    // Get primary image from images relationship if available
    String? imageUrl;
    if (json['images'] != null && json['images'].isNotEmpty) {
      imageUrl = json['images'][0]['image_url'];
    }

    return ItemSummary(
      id: json['id'],
      name: json['name'],
      primaryImageUrl: imageUrl,
    );
  }
}

class RatingStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution;

  RatingStats({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  factory RatingStats.fromJson(Map<String, dynamic> json) {
    final dist = json['rating_distribution'] as Map<String, dynamic>;
    return RatingStats(
      averageRating: (json['average_rating'] ?? 0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
      ratingDistribution: {
        5: int.parse(dist['5'].toString()),
        4: int.parse(dist['4'].toString()),
        3: int.parse(dist['3'].toString()),
        2: int.parse(dist['2'].toString()),
        1: int.parse(dist['1'].toString()),
      },
    );
  }
}
