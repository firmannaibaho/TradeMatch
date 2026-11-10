import 'package:flutter/material.dart';
import 'package:trade_match/services/supabase_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:trade_match/services/permission_service.dart';
import 'package:trade_match/models/item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'settings_page.dart';
import 'package:trade_match/theme.dart';
import 'package:trade_match/widgets/modern_card.dart';
import 'package:trade_match/widgets/glass_effects.dart';
import 'package:trade_match/widgets/modern_button.dart'; // Future use for Edit Profile

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SupabaseService _supabaseService = SupabaseService();
  Map<String, dynamic>? _userData;
  List<Item> _userItems = [];
  List<Map<String, dynamic>> _completedTrades = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userData = await _supabaseService.getCurrentUserProfile();
      final userItemsData = await _supabaseService.getUserItems();
      final completedTrades = await _supabaseService.getCompletedTrades();
      final userItems = userItemsData
          .map((data) => Item.fromJson(data))
          .toList();

      String? locationDisplay = userData?['default_location_city'];

      // If location is missing, try to fetch it
      if (locationDisplay == null || locationDisplay == 'Location not set') {
        try {
          bool hasPermission =
              await PermissionService.requestLocationPermission(context);
          if (hasPermission) {
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

              // Update local data clone
              if (userData != null) {
                userData['default_location_city'] = locationDisplay;
                // Optional: Sync to backend silently
                _supabaseService.updateProfile(
                  defaultLocationCity: locationDisplay,
                  defaultLat: position.latitude,
                  defaultLon: position.longitude,
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Failed to auto-fetch location: $e');
        }
      }

      if (mounted) {
        setState(() {
          _userData = userData;
          _userItems = userItems;
          _completedTrades = completedTrades;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_errorMessage),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : NestedScrollView(
                physics: const BouncingScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    pinned: true,
                    elevation: 0,
                    backgroundColor: AppColors.surface,
                    automaticallyImplyLeading: false,
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: GlassContainer(
                          borderRadius: 30.0,
                          padding: const EdgeInsets.all(4),
                          child: IconButton(
                            icon: const Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    expandedHeight: 340,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Background Image
                          (_userData?['background_picture_url'] != null)
                              ? CachedNetworkImage(
                                  imageUrl:
                                      _userData!['background_picture_url'],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.grey[900]),
                                  errorWidget: (context, url, error) =>
                                      Container(color: Colors.grey[800]),
                                )
                              : Container(
                                  color: Colors.grey[850],
                                ), // Dark fallback
                          // 2. Gradient Overlay (Darkens bottom for avatar contrast)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.transparent,
                                  AppColors.surface.withOpacity(0.8),
                                  AppColors.surface,
                                ],
                                stops: const [0.0, 0.4, 0.85, 1.0],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),

                          // 3. Avatar
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 30.0),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.2),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.grey[800],
                                  backgroundImage:
                                      _userData?['profile_picture_url'] != null
                                      ? NetworkImage(
                                              _userData!['profile_picture_url'],
                                            )
                                            as ImageProvider
                                      : const AssetImage(
                                          'assets/images/pp-1.png',
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(60),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                        ),
                        child: TabBar(
                          labelColor: Theme.of(context).primaryColor,
                          unselectedLabelColor: AppColors.textSecondary,
                          indicatorColor: Theme.of(context).primaryColor,
                          indicatorSize: TabBarIndicatorSize.label,
                          indicatorWeight: 3,
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'Ditawarkan'),
                            Tab(text: 'History'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 12.0,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _ProfileInfo(
                            userData: _userData,
                            itemCount: _userItems.length,
                            tradesCount: _completedTrades.length,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _ItemList(items: _userItems, isOffer: true),
                    _TradeHistoryList(
                      trades: _completedTrades,
                      currentUserId: _supabaseService.userId,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final int itemCount;
  final int tradesCount;

  const _ProfileInfo({
    this.userData,
    required this.itemCount,
    this.tradesCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final name = userData?['name'] ?? 'User';
    final location = userData?['default_location_city'] ?? 'Location not set';
    // Use actual item list length for "Offers" if available, else fallback to API count
    final offersCount = itemCount > 0
        ? itemCount.toString()
        : (userData?['offers_count']?.toString() ?? '0');
    final displayTradesCount = tradesCount > 0
        ? tradesCount.toString()
        : (userData?['trades_count']?.toString() ?? '0');

    return Column(
      children: [
        Text(name, style: AppTextStyles.heading2),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              location,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: offersCount,
                  title: 'Offers',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/trade_history'),
                  child: _StatCard(
                    value: displayTradesCount,
                    title: 'Trades',
                    icon: Icons.history,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String title;
  final IconData icon;

  const _StatCard({
    required this.value,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      backgroundColor:
          AppColors.surface, // Or strictly white/dark depending on theme
      elevation: 2,
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.heading3),
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// _StatItem removed as it is incorporated into _ProfileInfo with ModernCard logic

class _ItemList extends StatelessWidget {
  final bool isOffer;
  final List<Item> items;

  const _ItemList({required this.isOffer, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffer ? Icons.inventory_2_outlined : Icons.search_outlined,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isOffer ? 'No items offered yet' : 'No requests yet',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75, // Taller for image + text
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ModernCard(
          padding: EdgeInsets.zero,
          onTap: () {
            // TODO: Navigate to item detail
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: (item.images != null && item.images!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: item.images!.first.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey[200]),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelBold,
                      ),
                      Text(
                        item.condition,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Widget to display trade history - items that have been traded
class _TradeHistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> trades;
  final String? currentUserId;

  const _TradeHistoryList({
    required this.trades,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No completed trades yet',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your traded items will appear here',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: trades.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: 12), // Spacing instead of divider
      itemBuilder: (context, index) {
        final trade = trades[index];
        // Use snapshots if available (for deleted items), otherwise use relational data
        final itemA = trade['item_a_snapshot'] ?? trade['itemA'];
        final itemB = trade['item_b_snapshot'] ?? trade['itemB'];

        // Determine which item was the user's and which was the partner's
        // Note: For snapshots, user_id is in the top level of the item object
        final isUserItemA = itemA?['user_id'] == currentUserId;
        final myItem = isUserItemA ? itemA : itemB;
        final theirItem = isUserItemA ? itemB : itemA;

        final myItemImages = myItem?['images'] as List<dynamic>? ?? [];
        final theirItemImages = theirItem?['images'] as List<dynamic>? ?? [];

        final updatedAt = DateTime.tryParse(trade['updated_at'] ?? '');
        final formattedDate = updatedAt != null
            ? '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}'
            : '';

        return ModernCard(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text(
                      'Completed',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Trade items
              Row(
                children: [
                  // My item
                  Expanded(
                    child: Column(
                      children: [
                        ModernCard(
                          padding: EdgeInsets.zero,
                          height: 70,
                          width: 70,
                          child: (myItemImages.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl:
                                      myItemImages.first['image_url'] ?? '',
                                  fit: BoxFit.cover,
                                )
                              : const Center(
                                  child: Icon(Icons.image_not_supported),
                                ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          myItem?['title'] ?? 'Your Item',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Swap icon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                  ),
                  // Their item
                  Expanded(
                    child: Column(
                      children: [
                        ModernCard(
                          padding: EdgeInsets.zero,
                          height: 70,
                          width: 70,
                          child: (theirItemImages.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl:
                                      theirItemImages.first['image_url'] ?? '',
                                  fit: BoxFit.cover,
                                )
                              : const Center(
                                  child: Icon(Icons.image_not_supported),
                                ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          theirItem?['title'] ?? 'Their Item',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
