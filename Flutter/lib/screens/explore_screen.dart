import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:trade_match/models/barter_item.dart';
import 'package:trade_match/models/item.dart';
import 'package:trade_match/services/supabase_service.dart';
import 'package:trade_match/services/permission_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui'; // For ImageFilter (Glassmorphism)
import 'package:trade_match/theme.dart';
import 'package:trade_match/widgets/match_success_dialog.dart';
import 'package:trade_match/chat/chat_detail.dart';
import 'package:trade_match/screens/item_detail_page.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  // Animation Controllers
  late AnimationController _likeController;
  late Animation<double> _likeScale;
  late AnimationController _pulseController; // For Empty State Radar

  bool _showLike = false;
  late Future<List<BarterItem>> _itemsFuture;

  // Swipe direction tracking for overlay animation
  double _swipeOffset = 0.0;
  AxisDirection? _swipeDirection;

  // Dynamic user data
  List<Item> _userItems = [];
  int? _currentUserItemId;
  String _userLocation = 'Loading...';
  // Removed unused lat/lon fields to fix analyzer warnings
  bool _isLoadingUserData = true;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadExploreItems();

    // Heart Animation Setup
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.5,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_likeController);

    _likeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showLike = false);
        _likeController.reset();
      }
    });

    // Radar Pulse Animation Setup
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadUserData();
  }

  @override
  void dispose() {
    _likeController.dispose();
    _pulseController.dispose();
    _swiperController.dispose();
    super.dispose();
  }

  Future<List<BarterItem>> _loadExploreItems() async {
    try {
      final itemsData = await _supabaseService.getExploreFeed(limit: 20);
      return itemsData.map((data) => BarterItem.fromJson(data)).toList();
    } catch (e) {
      // Use logger mechanism or just print for now as per project style (but fix info warning later)
      debugPrint('Error loading explore items: $e');
      rethrow;
    }
  }

  Future<void> _loadUserData() async {
    try {
      if (mounted) {
        _hasLocationPermission =
            await PermissionService.requestLocationPermission(context);
      }
      final userData = await _supabaseService.getCurrentUserProfile();
      final userItemsData = await _supabaseService.getUserItems();
      final userItems = userItemsData
          .map((data) => Item.fromJson(data))
          .toList();

      if (mounted) {
        String locationDisplay =
            userData != null && userData['default_location_city'] != null
            ? userData['default_location_city']
            : 'Unknown';

        // Try to get real location
        if (_hasLocationPermission) {
          try {
            Position position = await Geolocator.getCurrentPosition();
            List<Placemark> placemarks = await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            );
            if (placemarks.isNotEmpty) {
              final place = placemarks[0];
              locationDisplay =
                  place.locality ??
                  place.subAdministrativeArea ??
                  'Unknown Location';
            }
          } catch (e) {
            debugPrint('Failed to get real location: $e');
            // Fallback to profile location is already set
          }
        }

        setState(() {
          _userLocation = locationDisplay;
          // Unused vars removed
          if (userItems.isNotEmpty) {
            final activeItems = userItems
                .where((item) => item.status == 'active')
                .toList();
            _userItems = activeItems.isNotEmpty ? activeItems : userItems;
            _currentUserItemId = _userItems.isNotEmpty
                ? _userItems.first.id
                : null;
          }
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _itemsFuture = _loadExploreItems();
    });
  }

  // UPDATED: onSwipeEnd signature for AppinioSwiper 2.0+
  // The callback provides (int previousIndex, int targetIndex, SwiperActivity activity)
  void _onSwipeEnd(
    int previousIndex,
    int targetIndex,
    SwiperActivity activity,
  ) async {
    // Only handle physical swipes (Left/Right)
    if (activity is! Swipe) return;

    // Haptic Feedback for physical interaction
    HapticFeedback.lightImpact();

    // Reset swipe overlay state
    setState(() {
      _swipeOffset = 0.0;
      _swipeDirection = null;
    });

    final direction = activity.direction;
    final items = await _itemsFuture;

    // Safety check: Use previousIndex valid for the item just swiped
    if (previousIndex < 0 || previousIndex >= items.length) return;

    final item = items[previousIndex];

    if (_currentUserItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an item to start trading')),
      );
      return;
    }

    if (direction == AxisDirection.right) {
      _processSwipe(item, 'like');
    } else if (direction == AxisDirection.left) {
      _processSwipe(item, 'skip');
    }
  }

  Future<void> _processSwipe(BarterItem item, String action) async {
    debugPrint('Processing $action on ${item.title}');
    try {
      final result = await _supabaseService.swipe(
        _currentUserItemId!,
        item.id,
        action,
      );

      if (action == 'like' && mounted && result['matched'] == true) {
        // Haptic Success
        HapticFeedback.heavyImpact();

        final myItem = _userItems.firstWhere(
          (i) => i.id == _currentUserItemId,
          orElse: () => _userItems.first,
        );
        _showMatchDialog(item, myItem, result['swap']['id'].toString());
      }
    } catch (e) {
      debugPrint('Swipe error: $e');
    }
  }

  void _showMatchDialog(BarterItem item, Item myItem, String swapId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MatchSuccessDialog(
        otherUserName: item.user.name,
        otherUserImage: item.user.profilePictureUrl,
        myItemTitle: myItem.title,
        theirItemTitle: item.title,
        swapId: swapId,
        onKeepSwiping: () => Navigator.of(context).pop(),
        onStartChat: (swapId, otherName, otherImage) {
          Navigator.of(context).pop();
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
  }

  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();
    setState(() => _showLike = true);
    _likeController.forward(from: 0);
    _swiperController.swipeRight();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(primary),
                _buildItemSelector(primary),
                Expanded(child: _buildSwiper(primary)),
                _buildActionButtons(primary),
              ],
            ),
            if (_showLike) _buildLikeOverlay(primary),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {}, // Profile tap
            child: const CircleAvatar(
              radius: 22,
              backgroundImage: AssetImage('assets/images/profile.jpg'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Discover', style: AppTextStyles.heading2),
                const SizedBox(height: 2),
                Text(
                  'Nearby • $_userLocation',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
            icon: Icon(
              Icons.notifications_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          /* ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 10,
              ),
            ),
            onPressed: () => Navigator.pushNamed(context, '/search'),
            child: const Icon(Icons.filter_list, color: Colors.white),
          ), */
        ],
      ),
    );
  }

  Widget _buildItemSelector(Color primary) {
    if (_userItems.isEmpty || _isLoadingUserData)
      return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DropdownButton<int>(
          value: _currentUserItemId,
          isExpanded: true,
          underline: const SizedBox(),
          icon: Icon(Icons.arrow_drop_down, color: primary),
          style: AppTextStyles.bodyMedium.copyWith(
            color: const Color(0xFF441606),
          ),
          items: _userItems
              .map(
                (item) => DropdownMenuItem<int>(
                  value: item.id,
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, color: primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Trading with: ${item.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (newItemId) {
            if (newItemId != null)
              setState(() => _currentUserItemId = newItemId);
          },
        ),
      ),
    );
  }

  Widget _buildSwiper(Color primary) {
    return FutureBuilder<List<BarterItem>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmer();
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading items', style: AppTextStyles.bodyLarge),
                TextButton(onPressed: _refreshFeed, child: const Text('Retry')),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final items = snapshot.data!;

        // Immersive Stack - No specific padding here, card handles margins
        return Stack(
          children: [
            Listener(
              onPointerMove: (event) {
                setState(() {
                  _swipeOffset =
                      event.localPosition.dx -
                      (MediaQuery.of(context).size.width / 2);
                  if (_swipeOffset > 20) {
                    _swipeDirection = AxisDirection.right;
                  } else if (_swipeOffset < -20) {
                    _swipeDirection = AxisDirection.left;
                  } else {
                    _swipeDirection = null;
                  }
                  _swipeOffset = _swipeOffset.abs();
                });
              },
              onPointerUp: (_) {
                // The offset will be reset in _onSwipeEnd
              },
              child: AppinioSwiper(
                controller: _swiperController,
                cardCount: items.length,
                loop: true,
                threshold: 150,
                onSwipeEnd: _onSwipeEnd,
                swipeOptions: const SwipeOptions.only(left: true, right: true),
                cardBuilder: (context, index) {
                  return GestureDetector(
                    onDoubleTap: _handleDoubleTap,
                    child: _buildCard(items[index]),
                  );
                },
              ),
            ),
            // Swipe direction overlay - Like indicator (right swipe)
            if (_swipeDirection == AxisDirection.right)
              Positioned(
                top: 40,
                right: 30,
                child: Opacity(
                  opacity: (_swipeOffset / 150).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            // Swipe direction overlay - Dislike indicator (left swipe)
            if (_swipeDirection == AxisDirection.left)
              Positioned(
                top: 40,
                left: 30,
                child: Opacity(
                  opacity: (_swipeOffset / 150).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor.withOpacity(
                    0.1 * (1 - _pulseController.value),
                  ),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(
                      0.5 * (1 - _pulseController.value),
                    ),
                    width: 2 + (10 * _pulseController.value),
                  ),
                ),
                child: const Icon(Icons.radar, size: 64, color: Colors.grey),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Searching for trades...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try expanding your search distance',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshFeed,
            child: const Text('Refresh Feed'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BarterItem item) {
    return GestureDetector(
      onLongPress: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ItemDetailPage(item: item)),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            margin: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              60,
            ), // Reduced margins for bigger card
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Main Image
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.images.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: item.images.first.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: Colors.grey[200]),
                          errorWidget: (context, url, err) => const Center(
                            child: Icon(Icons.error, color: Colors.grey),
                          ),
                        )
                      else
                        Container(color: Colors.grey[200]),

                      // Wants / Match Highlight (floating on image)
                      if (item.wantsDescription.isNotEmpty)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(
                                AppRadius.chip,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.flash_on,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 150,
                                  ),
                                  child: Text(
                                    "WANT: ${item.wantsDescription}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Info Content (White Area)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title & Price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTextStyles.heading3.copyWith(
                                // Smaller than heading1
                                fontSize: 22,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.estimatedValue != null)
                            Text(
                              currencyFormatter.format(item.estimatedValue),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Location & User
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.locationCity,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: item.user.profilePictureUrl != null
                                ? NetworkImage(item.user.profilePictureUrl!)
                                : null,
                            child: item.user.profilePictureUrl == null
                                ? const Icon(Icons.person, size: 12)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(item.user.name, style: AppTextStyles.labelBold),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(Color primary) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 34),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Skip Button
          _buildGlassActionButton(
            icon: Icons.close,
            color: const Color(0xFFFF5252), // Vibrant red
            size: 60, // Slightly smaller glass button
            onTap: () {
              HapticFeedback.lightImpact();
              _swiperController.swipeLeft();
            },
          ),
          const SizedBox(width: 32),
          // Like Button
          _buildGlassActionButton(
            icon: Icons.favorite,
            color: const Color(0xFF00E676), // Vibrant green for like
            size: 70, // Prominent
            onTap: () {
              HapticFeedback.mediumImpact();
              setState(() => _showLike = true);
              _likeController.forward(from: 0);
              _swiperController.swipeRight();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlassActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      borderRadius: size / 2, // Circle
      blurSigma: 15,
      width: size,
      height: size,
      color: Colors.black.withOpacity(0.3),
      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Center(
            child: Icon(icon, color: color, size: size * 0.45),
          ),
        ),
      ),
    );
  }

  // _buildCircleButton removed as it is replaced by _buildGlassActionButton

  Widget _buildLikeOverlay(Color primary) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _likeController,
            builder: (context, child) {
              final scale = _likeScale.value;
              final opacity = (_likeController.value > 0.1)
                  ? (1.0 - _likeController.value * 0.8)
                  : 1.0;
              return Opacity(
                opacity: opacity,
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: Icon(Icons.favorite, color: primary, size: 120),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          ),
        ),
      ),
    );
  }
}
