import 'package:flutter/material.dart';
import 'package:trade_match/models/barter_item.dart';
import 'package:trade_match/services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Phase 3: Performance
import 'package:trade_match/screens/submit_review_page.dart';
import 'package:trade_match/theme/app_colors.dart';

class TradeHistoryPage extends StatefulWidget {
  const TradeHistoryPage({super.key});

  @override
  State<TradeHistoryPage> createState() => _TradeHistoryPageState();
}

class _TradeHistoryPageState extends State<TradeHistoryPage> {
  final SupabaseService _supabaseService = SupabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade History'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: TabBar(
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTradeList('active'),
                  _buildTradeList('trade_complete'),
                  _buildTradeList('cancelled'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeList(String status) {
    return FutureBuilder<List<BarterMatch>>(
      future: _supabaseService.getSwaps(status: status).then((swapsData) {
        return swapsData.map((data) => BarterMatch.fromJson(data)).toList();
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No ${status == 'active'
                      ? 'active'
                      : status == 'trade_complete'
                      ? 'completed'
                      : 'cancelled'} trades',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final trades = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: trades.length,
          itemBuilder: (context, index) {
            final swap = trades[index];
            return _buildTradeCard(context, swap: swap);
          },
        );
      },
    );
  }

  Widget _buildTradeCard(BuildContext context, {required BarterMatch swap}) {
    // Determine which item belongs to current user and which is the other
    final currentUserId = _supabaseService.userId; // Get from Supabase service
    final isUserItemA = swap.itemA.user.id == currentUserId;
    final myItem = isUserItemA ? swap.itemA : swap.itemB;
    final theirItem = isUserItemA ? swap.itemB : swap.itemA;
    final otherUser = isUserItemA ? swap.itemB.user : swap.itemA.user;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trade ID and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trade #${swap.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildStatusChip(swap.status),
              ],
            ),
            const SizedBox(height: 16),

            // Trade Items
            Row(
              children: [
                Expanded(
                  child: _buildTradeItemPreview(
                    title: 'Your Item',
                    itemName: myItem.title,
                    imageUrl: myItem.images.isNotEmpty
                        ? myItem.images.first.imageUrl
                        : null,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.swap_horiz,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildTradeItemPreview(
                    title: 'Their Item',
                    itemName: theirItem.title,
                    imageUrl: theirItem.images.isNotEmpty
                        ? theirItem.images.first.imageUrl
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Trade Partner
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[200],
                  backgroundImage:
                      otherUser.profilePictureUrl != null &&
                          otherUser.profilePictureUrl!.isNotEmpty
                      ? NetworkImage(otherUser.profilePictureUrl!)
                      : null,
                  child:
                      otherUser.profilePictureUrl == null ||
                          otherUser.profilePictureUrl!.isEmpty
                      ? Text(
                          otherUser.name.isNotEmpty
                              ? otherUser.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  otherUser.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  _formatDate(swap.updatedAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            if (swap.status == 'trade_complete') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubmitReviewPage(swap: swap),
                      ),
                    );

                    if (result == true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Review submitted successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.rate_review),
                  label: const Text('Write Review'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            if (swap.status == 'active') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleCancel(swap.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleComplete(swap.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Complete'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancel(int swapId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Trade'),
        content: const Text('Are you sure you want to cancel this trade?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.cancelTrade(swapId);
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trade cancelled successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error cancelling trade: $e')));
        }
      }
    }
  }

  Future<void> _handleComplete(int swapId) async {
    try {
      // Call the confirm endpoint
      final response = await _supabaseService.confirmTrade(swapId);
      if (mounted) {
        setState(() {}); // Refresh the list
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Trade confirmed!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildTradeItemPreview({
    required String title,
    required String itemName,
    String? imageUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 150, // Small thumbnail
                        placeholder: (context, url) =>
                            Container(color: Colors.grey[300]),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image, size: 20),
                      ),
                    )
                  : const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                itemName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (status) {
      case 'active':
      case 'chatting':
      case 'location_suggested':
      case 'location_agreed':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        text = 'Active';
        break;
      case 'trade_complete':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        text = 'Completed';
        break;
      case 'cancelled':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        text = 'Cancelled';
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
