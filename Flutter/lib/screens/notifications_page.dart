import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trade_match/theme.dart';
import 'package:trade_match/models/notification.dart' as app;
import 'package:trade_match/services/supabase_service.dart';
import 'package:trade_match/chat/chat_detail.dart';
import 'package:trade_match/screens/trade_history_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final SupabaseService _supabaseService = SupabaseService();
  List<app.AppNotification> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;
  String? _error;
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notificationChannel?.unsubscribe();
    super.dispose();
  }

  /// Subscribe to real-time notification updates
  void _subscribeToNotifications() {
    final userId = _supabaseService.userId;
    if (userId == null) return;

    try {
      _notificationChannel = Supabase.instance.client
          .channel('notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              if (mounted) {
                // Add new notification to the top of the list
                final newNotification = app.AppNotification.fromJson(
                  payload.newRecord,
                );
                setState(() {
                  _notifications.insert(0, newNotification);
                  if (!newNotification.isRead) {
                    _unreadCount++;
                  }
                });
              }
            },
          )
          .subscribe();
      print('✅ Subscribed to notifications realtime');
    } catch (e) {
      print('❌ Error subscribing to notifications: $e');
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabaseService.getNotifications();
      setState(() {
        _notifications = response
            .map((json) => app.AppNotification.fromJson(json))
            .toList();
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load notifications: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all as read'),
            ),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 14,
                                width: double.infinity,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 12,
                                width: 150,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : _error != null
          ? _buildErrorState()
          : _notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  return _buildNotificationItem(_notifications[index]);
                },
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
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadNotifications,
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
          Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll notify you when something happens',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(app.AppNotification notification) {
    return InkWell(
      onTap: () => _handleNotificationTap(notification),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: notification.isRead
              ? null
              : Theme.of(context).colorScheme.primary.withOpacity(0.05),
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getNotificationColor(
                  notification.type,
                ).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getNotificationIcon(notification.type),
                color: _getNotificationColor(notification.type),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title, style: AppTextStyles.labelBold),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(notification.createdAt),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Action
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getNotificationColor(app.NotificationType type) {
    switch (type) {
      case app.NotificationType.newSwap:
        return Colors.green;
      case app.NotificationType.newMessage:
        return AppColors.primary;
      case app.NotificationType.swapStatusChange:
        return Colors.blue;
      case app.NotificationType.system:
        return Colors.orange;
    }
  }

  IconData _getNotificationIcon(app.NotificationType type) {
    switch (type) {
      case app.NotificationType.newSwap:
        return Icons.favorite;
      case app.NotificationType.newMessage:
        return Icons.chat_bubble;
      case app.NotificationType.swapStatusChange:
        return Icons.swap_horiz;
      case app.NotificationType.system:
        return Icons.info;
    }
  }

  String _formatTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _handleNotificationTap(app.AppNotification notification) async {
    // Mark as read
    if (!notification.isRead) {
      try {
        await _supabaseService.markNotificationAsRead(notification.id);
        setState(() {
          notification = app.AppNotification(
            id: notification.id,
            userId: notification.userId,
            type: notification.type,
            title: notification.title,
            message: notification.message,
            data: notification.data,
            isRead: true,
            createdAt: notification.createdAt,
          );
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        });
      } catch (e) {
        // Silently fail if marking as read fails
      }
    }

    // Navigate based on notification type
    if (!mounted) return;

    switch (notification.type) {
      case app.NotificationType.newSwap:
      case app.NotificationType.newMessage:
        // Navigate to chat detail if swap_id is available
        final swapId = notification.data?['swap_id'];
        if (swapId != null) {
          // Note: ChatDetailPage expects a BarterMatch object, but we only have swap_id
          // For now, navigate to Trade History where they can see all swaps
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TradeHistoryPage()),
          );
        }
        break;
      case app.NotificationType.swapStatusChange:
        // Navigate to trade history
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TradeHistoryPage()),
        );
        break;
      case app.NotificationType.system:
        // No navigation for system notifications
        break;
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _supabaseService.markAllNotificationsAsRead();
      setState(() {
        for (var i = 0; i < _notifications.length; i++) {
          final n = _notifications[i];
          _notifications[i] = app.AppNotification(
            id: n.id,
            userId: n.userId,
            type: n.type,
            title: n.title,
            message: n.message,
            data: n.data,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        _unreadCount = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
      }
    }
  }
}
