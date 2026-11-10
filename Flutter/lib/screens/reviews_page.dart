import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trade_match/models/review.dart';
import 'package:trade_match/services/supabase_service.dart';

class ReviewsPage extends StatefulWidget {
  final String userId;

  const ReviewsPage({super.key, required this.userId});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Review> _reviews = [];
  RatingStats? _ratingStats;
  bool _isLoading = true;
  String? _error;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _reviews.clear();
        _hasMore = true;
        _isLoading = true;
        _error = null;
      });
    }

    if (!_hasMore && !refresh) return;

    try {
      final response = await _supabaseService.getUserReviews(
        widget.userId,
      );

      setState(() {
        final newReviews = (response as List)
            .map((json) => Review.fromJson(json))
            .toList();

        if (refresh) {
          _reviews = newReviews;
        } else {
          _reviews.addAll(newReviews);
        }

        // Note: Supabase service returns simple list, no pagination or stats
        // TODO: Implement pagination and stats in SupabaseService if needed
        _hasMore = false; // Disable pagination for now
        _ratingStats = null; // No stats available yet

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load reviews: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews & Ratings'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading && _reviews.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _reviews.isEmpty
          ? _buildErrorState()
          : _reviews.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () => _loadReviews(refresh: true),
              child: Column(
                children: [
                  if (_ratingStats != null) _buildRatingSummary(),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviews.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _reviews.length) {
                          // Load more indicator
                          _loadReviews();
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _buildReviewCard(_reviews[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _loadReviews(refresh: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No reviews yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This user hasn\'t received any reviews',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSummary() {
    final stats = _ratingStats!;

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        children: [
          // Overall Rating
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  stats.averageRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final whole = stats.averageRating.floor();
                    final hasHalf = stats.averageRating - whole >= 0.5;

                    return Icon(
                      index < whole
                          ? Icons.star
                          : (index == whole && hasHalf)
                          ? Icons.star_half
                          : Icons.star_border,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on ${stats.totalReviews} review${stats.totalReviews != 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          // Rating Bars
          Expanded(
            flex: 3,
            child: Column(
              children: [
                for (int i = 5; i >= 1; i--)
                  _buildRatingBar(
                    context,
                    i,
                    stats.totalReviews > 0
                        ? stats.ratingDistribution[i]! / stats.totalReviews
                        : 0,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(BuildContext context, int rating, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$rating',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const Icon(Icons.star, size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(percentage * 100).round()}%',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info and Rating
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: review.reviewer.profilePictureUrl != null
                      ? NetworkImage(review.reviewer.profilePictureUrl!)
                      : null,
                  child: review.reviewer.profilePictureUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.reviewer.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat.yMMMd().format(review.createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star,
                      size: 16,
                      color: index < review.rating
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[300],
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Trade Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                      image: review.swap.itemA.primaryImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(
                                review.swap.itemA.primaryImageUrl!,
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: review.swap.itemA.primaryImageUrl == null
                        ? const Icon(Icons.image_not_supported, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.swap.itemA.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Traded with ${review.swap.itemB.name}',
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Review Text
            if (review.comment != null) ...[
              const SizedBox(height: 12),
              Text(review.comment!, style: const TextStyle(height: 1.5)),
            ],

            // Review Photos
            if (review.photos != null && review.photos!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.photos!.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(review.photos![index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
