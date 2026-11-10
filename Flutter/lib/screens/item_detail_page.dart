import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:trade_match/models/barter_item.dart';
import 'package:trade_match/models/item.dart';
import 'package:trade_match/profile/profile.dart';
import 'package:trade_match/services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Phase 3: Performance
import 'package:trade_match/theme.dart';
import 'package:trade_match/widgets/match_success_dialog.dart';
import 'package:trade_match/chat/chat_detail.dart';
import 'package:trade_match/widgets/modern_card.dart';
import 'package:trade_match/widgets/glass_effects.dart';
import 'package:trade_match/widgets/modern_button.dart';

final currencyFormatter = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

class ItemDetailPage extends StatefulWidget {
  final BarterItem item;

  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLiking = false;

  Future<void> _handleLike() async {
    if (_isLiking) return;

    setState(() {
      _isLiking = true;
    });

    try {
      // Get current user's items to find an item to use for swiping
      // In ExploreScreen, this is pre-loaded. Here we load on demand (or could pre-load).
      // Optimization: Could check if we already have items in a provider or previous screen
      final userItemsData = await _supabaseService.getUserItems();
      final userItems = userItemsData
          .map((data) => Item.fromJson(data))
          .toList();

      if (userItems.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to create an item first to start trading'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLiking = false;
        });
        return;
      }

      // Use the first available active item, or just the first item
      final activeItems = userItems
          .where((item) => item.status == 'active')
          .toList();
      final myItem = activeItems.isNotEmpty
          ? activeItems.first
          : userItems.first;

      // Call swipe API with 'like' action
      final result = await _supabaseService.swipe(
        myItem.id,
        widget.item.id,
        'like',
      );

      if (!mounted) return;

      if (result['matched'] == true) {
        // MATCH! Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => MatchSuccessDialog(
            otherUserName: widget.item.user.name,
            otherUserImage: widget.item.user.profilePictureUrl,
            myItemTitle: myItem.title,
            theirItemTitle: widget.item.title,
            swapId: result['swap']['id'].toString(),
            onKeepSwiping: () => Navigator.of(context).pop(),
            onStartChat: (swapId, otherName, otherImage) {
              Navigator.of(context).pop(); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailPage(
                    matchId: swapId,
                    otherUserName: otherName,
                    otherUserImage: otherImage,
                  ),
                ),
              );
            },
          ),
        );
      } else {
        // Just a like, no match yet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Liked ${widget.item.title}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to like item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GlassContainer(
                borderRadius: 30.0,
                padding: EdgeInsets.zero,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: widget.item.images.isNotEmpty
                        ? widget.item.images.length
                        : 1,
                    itemBuilder: (context, index) {
                      if (widget.item.images.isEmpty) {
                        return const Center(
                          child: Icon(Icons.image_not_supported),
                        );
                      }
                      return CachedNetworkImage(
                        imageUrl: widget.item.images[index].imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 1200, // Full-size detail images
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image, size: 50),
                        ),
                      );
                    },
                  ),
                  // Gradient Overlay for text readability (optional, but good for parallax)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                        stops: const [0.0, 0.2, 0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Item details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                24,
                16,
                120,
              ), // Extra bottom padding for floating bar
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price Card
                  ModernCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.item.title,
                                style: AppTextStyles.heading2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (widget.item.estimatedValue != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(context).primaryColor.withBlue(200),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              currencyFormatter.format(
                                widget.item.estimatedValue,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Owner info Card
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/reviews',
                        arguments: widget.item.user.id,
                      );
                    },
                    child: ModernCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  widget.item.user.profilePictureUrl != null
                                  ? NetworkImage(
                                      widget.item.user.profilePictureUrl!,
                                    )
                                  : null,
                              child: widget.item.user.profilePictureUrl == null
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.item.user.name,
                                  style: AppTextStyles.labelBold,
                                ),
                                Text(
                                  widget.item.user.createdAt != null
                                      ? 'Joined ${DateFormat.yMMMd().format(widget.item.user.createdAt!)}'
                                      : 'Member',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.item.user.rating != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.chip,
                                ),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 18,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.item.user.rating!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('Description', style: AppTextStyles.heading3),
                  ),
                  const SizedBox(height: 8),
                  ModernCard(
                    child: Text(
                      widget.item.description,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Looking for
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Looking to Trade For',
                      style: AppTextStyles.heading3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ModernCard(
                    child: SizedBox(
                      width: double.infinity,
                      child: widget.item.wants.isNotEmpty
                          ? Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.item.wants
                                  .map(
                                    (want) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.chip,
                                        ),
                                        border: Border.all(
                                          color: AppColors.primary.withOpacity(
                                            0.2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        want.category?.name ?? 'Unknown',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            )
                          : Text(
                              'Open to offers',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Location
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('Location', style: AppTextStyles.heading3),
                  ),
                  const SizedBox(height: 8),
                  ModernCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_outlined,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          widget.item.locationCity,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      extendBody: true, // Allow body to scroll behind floating UI
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: GlassContainer(
          borderRadius: AppRadius.button,
          blurSigma: 15,
          color: Colors.white.withOpacity(
            0.8,
          ), // Translucent white for glass effect
          padding: const EdgeInsets.all(8),
          child: ModernButton(
            text: _isLiking ? 'Matching...' : 'I Want This!',
            icon: _isLiking ? null : Icons.favorite,
            isLoading: _isLiking,
            style: ModernButtonStyle
                .primary, // This uses the gradient/shadow logic inside ModernButton or similar
            height: 56,
            onPressed: _isLiking ? null : _handleLike,
          ),
        ),
      ),
    );
  }
}
