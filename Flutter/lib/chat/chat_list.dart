import 'package:flutter/material.dart';
import 'package:trade_match/chat/chat_detail.dart';
import 'package:trade_match/models/barter_item.dart';
import 'package:trade_match/models/user.dart';
import 'package:trade_match/services/supabase_service.dart';
import 'package:trade_match/theme.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<BarterMatch> _swaps = [];
  bool _isLoading = true;
  String? _error;
  Map<int, int> _unreadCounts = {}; // swapId -> unread count

  @override
  void initState() {
    super.initState();
    _loadSwaps();
  }

  Future<void> _loadUnreadCounts() async {
    final supabaseService = SupabaseService();
    for (final swap in _swaps) {
      try {
        final count = await supabaseService.getUnreadMessageCount(swap.id);
        if (mounted) {
          setState(() {
            _unreadCounts[swap.id] = count;
          });
        }
      } catch (e) {
        print('Error loading unread count for swap ${swap.id}: $e');
      }
    }
  }

  Future<void> _loadSwaps() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final swapsData = await SupabaseService().getSwaps();
      final swaps = swapsData
          .map((data) => BarterMatch.fromJson(data))
          .toList();
      if (mounted) {
        setState(() {
          _swaps = swaps;
          _isLoading = false;
        });
        // Load unread counts after swaps are loaded
        _loadUnreadCounts();
      }
    } catch (e, stackTrace) {
      print('Error loading swaps: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Determine the "other user" in a swap based on current user
  User _getOtherUser(BarterMatch swap) {
    // Compare current user ID with item owners (UUID strings)
    final currentUserId = SupabaseService().userId; // UUID string
    if (swap.itemA.user.id == currentUserId) {
      return swap.itemB.user;
    }
    return swap.itemA.user;
  }

  /// Get other user's item for display
  BarterItem _getOtherItem(BarterMatch swap) {
    final currentUserId = SupabaseService().userId; // UUID string
    if (swap.itemA.user.id == currentUserId) {
      return swap.itemB;
    }
    return swap.itemA;
  }

  /// Format time ago
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  /// Get message preview text
  String _getMessagePreview(BarterMatch swap) {
    if (swap.latestMessage == null) {
      return 'Start chatting about the trade...';
    }

    final msg = swap.latestMessage!;
    switch (msg.type) {
      case 'location':
        return '📍 Meeting location suggested';
      case 'location_agreement':
        return '✅ Location agreed!';
      default:
        return msg.messageText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color background = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // Header & Search Section (Non-scrollable)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Messages",
                    style: AppTextStyles.heading1.copyWith(
                      color: const Color(0xFF441606),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Modern Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        AppRadius.pill,
                      ), // Pill shape
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search conversations...",
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Content List
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Failed to load conversations',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadSwaps, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_swaps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 60,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No conversations yet',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Matches will appear here.\nStart swiping to find trades!',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSwaps,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _swaps.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final swap = _swaps[index];
          final otherUser = _getOtherUser(swap);
          final otherItem = _getOtherItem(swap);

          return _conversationCard(
            context,
            swap.id.toString(),
            otherUser.name,
            otherUser.profilePictureUrl,
            otherItem.title,
            _getMessagePreview(swap),
            _formatTimeAgo(swap.updatedAt),
            _unreadCounts[swap.id] ?? 0,
          );
        },
      ),
    );
  }

  Widget _conversationCard(
    BuildContext context,
    String swapId,
    String name,
    String? imageUrl,
    String itemTitle,
    String preview,
    String time,
    int unreadCount,
  ) {
    return ModernCard(
      padding: EdgeInsets.zero,
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              matchId: swapId,
              otherUserName: name,
              otherUserImage: imageUrl,
            ),
          ),
        );
        // Refresh unread counts when returning
        _loadUnreadCounts();
      },
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Avatar with unread indicator (optional)
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2), // Border space
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: unreadCount > 0
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: AppTextStyles.heading3.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          )
                        : null,
                  ),
                ),
                // Online status could go here
              ],
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.labelBold.copyWith(
                            fontSize: 16,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: unreadCount > 0
                              ? Theme.of(context).primaryColor
                              : AppColors.textTertiary,
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // "Re: Item" context
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Trading: $itemTitle',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Last Message
                            Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: unreadCount > 0
                                    ? Colors.black87
                                    : AppColors.textSecondary,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Unread Badge
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
