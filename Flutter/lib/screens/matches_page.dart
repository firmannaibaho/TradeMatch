import 'package:flutter/material.dart';
import 'package:trade_match/chat/chat_detail.dart';
import 'package:trade_match/models/barter_item.dart';
import 'package:trade_match/services/supabase_service.dart';
import 'package:trade_match/models/user.dart';
import 'package:trade_match/models/category.dart';
import 'package:trade_match/models/item_image.dart';
import 'package:trade_match/theme.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _supabaseService = SupabaseService();
  late Future<List<BarterMatch>> _swapsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _swapsFuture = _supabaseService.getSwaps().then((swapsData) {
      return swapsData.map((data) => BarterMatch.fromJson(data)).toList();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches & Likes'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Matches'),
            Tab(text: 'Likes'),
          ],
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMatchesTab(), _buildLikesTab()],
      ),
    );
  }

  Widget _buildMatchesTab() {
    return FutureBuilder<List<BarterMatch>>(
      future: _swapsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _swapsFuture = _supabaseService.getSwaps().then((swapsData) {
                  return swapsData
                      .map((data) => BarterMatch.fromJson(data))
                      .toList();
                });
              });
              await _swapsFuture;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: const Center(child: Text('No matches yet')),
                  ),
                );
              },
            ),
          );
        }

        final swaps = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _swapsFuture = _supabaseService.getSwaps().then((swapsData) {
                return swapsData
                    .map((data) => BarterMatch.fromJson(data))
                    .toList();
              });
            });
            await _swapsFuture;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: swaps.length,
            itemBuilder: (context, index) {
              final swap = swaps[index];
              // Determine which item is the "other" item (not the current user's)
              // For simplicity in this demo, we'll assume itemB is the other item
              // In a real app, check current user ID against itemA/itemB owner
              final otherItem = swap.itemB;

              return AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 100),
                child: _buildMatchCard(
                  isMatch: true,
                  name: otherItem.user.name,
                  item: otherItem.title,
                  matchDate:
                      swap.itemA.updatedAt ??
                      swap
                          .itemA
                          .createdAt, // Fallback to createdAt if updatedAt is null
                  barterItem: otherItem,
                  matchId: swap.id.toString(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLikesTab() {
    return FutureBuilder<List<BarterItem>>(
      future: _supabaseService.getLikes().then((likesData) {
        return likesData.map((data) => BarterItem.fromJson(data)).toList();
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No likes yet'));
        }

        final likes = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: likes.length,
          itemBuilder: (context, index) {
            final item = likes[index];
            return AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 100),
              child: _buildMatchCard(
                isMatch: false,
                name: item.user.name,
                item: item.title,
                matchDate:
                    DateTime.now(), // Placeholder as we don't have like date
                barterItem: item,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMatchCard({
    required bool isMatch,
    required String name,
    required String item,
    required DateTime matchDate,
    BarterItem? barterItem,
    String? matchId,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (barterItem != null) {
            Navigator.pushNamed(context, '/item_detail', arguments: barterItem);
          } else {
            // Fallback for demo likes
            final demoItem = BarterItem(
              id: 0,
              title: item,
              description: 'Description for $item',
              condition: 'Good',
              estimatedValue: 100000,
              currency: 'IDR',
              locationCity: 'Jakarta',
              locationLat: -6.2088,
              locationLon: 106.8456,
              wantsDescription: 'Anything',
              status: 'active',
              createdAt: DateTime.now(),
              // updatedAt is now optional
              user: User(
                id: '0', // UUID string, not int
                name: name,
                // email is now optional
                profilePictureUrl: 'https://picsum.photos/200',
                defaultLocationCity: 'Jakarta',
              ),
              category: Category(id: 0, name: 'General', iconUrl: null),
              images: [
                ItemImage(
                  id: 0,
                  itemId: 0,
                  imageUrl: 'https://picsum.photos/500/300',
                  sortOrder: 0,
                ),
              ],
              wants: [],
            );
            Navigator.pushNamed(context, '/item_detail', arguments: demoItem);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile Image
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[200],
                backgroundImage:
                    barterItem?.user.profilePictureUrl != null &&
                        barterItem!.user.profilePictureUrl!.isNotEmpty
                    ? NetworkImage(barterItem.user.profilePictureUrl!)
                    : null,
                child:
                    barterItem?.user.profilePictureUrl == null ||
                        barterItem!.user.profilePictureUrl!.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Interested in: $item',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(matchDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // Action Button
              if (isMatch)
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    if (matchId != null && barterItem != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatDetailPage(
                            matchId: matchId,
                            otherUserName: name,
                            otherUserImage: barterItem.user.profilePictureUrl,
                          ),
                        ),
                      );
                    }
                  },
                )
              else
                TextButton(
                  onPressed: () {
                    // View item logic same as tap
                    if (barterItem != null) {
                      Navigator.pushNamed(
                        context,
                        '/item_detail',
                        arguments: barterItem,
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Text('View Item'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
