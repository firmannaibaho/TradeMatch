import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter
import 'package:trade_match/theme.dart';
import 'package:trade_match/chat/location_picker_modal.dart';
import 'package:trade_match/chat/location_message_bubble.dart';

import 'package:trade_match/widget_Template/loading_overlay.dart';
import 'package:trade_match/services/supabase_service.dart';
import 'package:trade_match/services/meetup_service.dart';
import 'package:trade_match/models/meetup.dart';
import 'package:trade_match/chat/meetup_banner.dart';
import 'package:trade_match/chat/meetup_scheduler_sheet.dart';
import 'package:trade_match/screens/meetup_tracking_page.dart';
import 'package:trade_match/widgets/trade_complete_dialog.dart';
import 'package:trade_match/screens/submit_review_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trade_match/widgets/pulsing_icon.dart'; // NEW: Pending trade animation

class ChatDetailPage extends StatefulWidget {
  final String matchId;
  final String otherUserName;
  final String? otherUserImage;

  const ChatDetailPage({
    super.key,
    required this.matchId,
    required this.otherUserName,
    this.otherUserImage,
  });

  @override
  _ChatDetailPageState createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseService _supabaseService = SupabaseService();
  List<dynamic> messages = [];
  String? currentUserId;
  bool isLoading = false;
  bool _meetupBusy = false;
  Map<String, dynamic>? swapData;
  RealtimeChannel? _messageChannel;
  RealtimeChannel? _swapChannel; // NEW: For listening to swap status changes

  Meetup? get _meetup =>
      swapData == null ? null : Meetup.fromSwap(swapData!);

  @override
  void initState() {
    super.initState();
    MeetupService.instance.addListener(_onMeetupChanged);
    _loadMessages();
    _loadSwapData();
    // Use Supabase user ID directly
    currentUserId = _supabaseService.userId;
    _subscribeToMessages();
    _subscribeToSwapChanges(); // NEW: Subscribe to swap status updates
  }

  void _onMeetupChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSwapData() async {
    try {
      final swapId = int.tryParse(widget.matchId);
      if (swapId == null) return;

      final data = await _supabaseService.getSwap(swapId);
      if (mounted) {
        setState(() {
          swapData = data;
        });
      }
    } catch (e) {
      print('Error loading swap data: $e');
    }
  }

  Future<void> _confirmTrade() async {
    try {
      setState(() => isLoading = true);

      final swapId = int.tryParse(widget.matchId);
      if (swapId == null) throw Exception('Invalid swap ID');

      final response = await _supabaseService.confirmTrade(swapId);

      // Reload swap data to get updated confirmation status
      await _loadSwapData();

      if (mounted) {
        setState(() => isLoading = false);

        // Check if both users have confirmed
        final bothConfirmed =
            swapData?['item_a_owner_confirmed'] == true &&
            swapData?['item_b_owner_confirmed'] == true;

        if (bothConfirmed) {
          // Show trade complete dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => TradeCompleteDialog(
              onLeaveReview: () {
                Navigator.of(context).pop();
                // Navigate to review page - determine other user
                final String? userAId = swapData?['user_a_id']?.toString();
                final String? userBId = swapData?['user_b_id']?.toString();
                final String? otherUserId = (userAId == currentUserId)
                    ? userBId
                    : userAId;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubmitReviewPage(
                      swapId: swapId,
                      reviewedUserId: otherUserId,
                      reviewedUserName: widget.otherUserName,
                    ),
                  ),
                );
              },
              onClose: () => Navigator.of(context).pop(),
            ),
          );
        } else {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trade confirmed! Waiting for partner...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming trade: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _subscribeToMessages() {
    final swapId = int.tryParse(widget.matchId);
    if (swapId == null) {
      print('Invalid swap ID for realtime subscription');
      return;
    }

    try {
      _messageChannel = Supabase.instance.client
          .channel('messages:swap_$swapId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'swap_id',
              value: swapId,
            ),
            callback: (payload) {
              if (mounted) {
                setState(() {
                  // Check if message already exists to avoid duplicates
                  final newMessage = payload.newRecord;
                  final exists = messages.any(
                    (m) => m['id'] == newMessage['id'],
                  );
                  if (!exists) {
                    messages.add(newMessage);
                    _scrollToBottom();
                  }
                });
              }
            },
          )
          .subscribe();
      print('✅ Subscribed to messages for swap $swapId');
    } catch (e) {
      print('❌ Error subscribing to messages: $e');
    }
  }

  /// NEW: Subscribe to swap status changes for real-time trade completion detection
  void _subscribeToSwapChanges() {
    final swapId = int.tryParse(widget.matchId);
    if (swapId == null) {
      print('Invalid swap ID for swap realtime subscription');
      return;
    }

    try {
      _swapChannel = Supabase.instance.client
          .channel('swap_updates:swap_$swapId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'swaps',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: swapId,
            ),
            callback: (payload) async {
              final newRecord = payload.newRecord;
              final newStatus = newRecord['status'];

              print('✅ Swap $swapId status changed to: $newStatus');

              // If trade is now complete, reload swap data and show dialog
              if (newStatus == 'trade_complete') {
                await _loadSwapData();

                if (mounted) {
                  // Show Trade Complete Dialog for BOTH users
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => TradeCompleteDialog(
                      onLeaveReview: () {
                        Navigator.of(context).pop();
                        // Navigate to review page
                        final String? userAId = swapData?['user_a_id']
                            ?.toString();
                        final String? userBId = swapData?['user_b_id']
                            ?.toString();
                        final String? otherUserId = (userAId == currentUserId)
                            ? userBId
                            : userAId;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SubmitReviewPage(
                              swapId: swapId,
                              reviewedUserId: otherUserId,
                              reviewedUserName: widget.otherUserName,
                            ),
                          ),
                        );
                      },
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  );
                }
              } else {
                // Update swap data for other status changes (e.g., confirmation flags)
                if (mounted) {
                  setState(() {
                    swapData = newRecord;
                  });
                }
              }
            },
          )
          .subscribe();
      print('✅ Subscribed to swap updates for swap $swapId');
    } catch (e) {
      print('❌ Error subscribing to swap updates: $e');
    }
  }

  Future<void> _loadMessages() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final swapId = int.tryParse(widget.matchId);
      if (swapId == null) {
        throw Exception('Invalid swap ID');
      }

      final messagesData = await _supabaseService.getMessages(swapId);

      // Mark messages as read when viewing the chat
      await _supabaseService.markMessagesAsRead(swapId);

      if (mounted) {
        setState(() {
          messages = messagesData;
          isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({
    required String content,
    String type = 'text',
    Map<String, dynamic>? locationData,
  }) async {
    if (content.isEmpty) return;

    try {
      final swapId = int.tryParse(widget.matchId);
      if (swapId == null) {
        throw Exception('Invalid swap ID');
      }

      print('📤 Sending message to swap $swapId: $content');

      // Send message with optional location data
      await _supabaseService.sendMessage(
        swapId,
        content,
        type: type,
        locationLat: locationData?['lat']?.toDouble(),
        locationLon: locationData?['lng']?.toDouble(),
        locationName: locationData?['location_name'],
        locationAddress: locationData?['location_address'],
      );

      print('✅ Message sent successfully');
      _messageController.clear();
      await _loadMessages();
    } catch (e, stackTrace) {
      print('❌ Error sending message: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }
  }

  Future<void> _showLocationPicker() async {
    final swapId = int.tryParse(widget.matchId);
    if (swapId != null && (_meetup == null || _meetup!.canPropose)) {
      await _openMeetupScheduler();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => LocationPickerModal(
        onLocationPicked: (name, address, lat, lng) {
          _sendMessage(
            content: 'Meeting location: $name',
            type: 'location',
            locationData: {
              'lat': lat,
              'lng': lng,
              'location_name': name,
              'location_address': address,
            },
          );
        },
      ),
    );
  }

  Future<void> _openMeetupScheduler() async {
    final swapId = int.tryParse(widget.matchId);
    if (swapId == null) return;
    final proposed = await MeetupSchedulerSheet.show(
      context,
      swapId: swapId,
      partnerName: widget.otherUserName,
      existing: _meetup,
    );
    if (proposed == true && mounted) {
      await _loadSwapData();
      await _loadMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajakan janji temu terkirim!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _acceptMeetup() async {
    final swapId = int.tryParse(widget.matchId);
    if (swapId == null) return;
    setState(() => _meetupBusy = true);
    try {
      await MeetupService.instance.acceptMeetup(swapId);
      await _loadSwapData();
      await _loadMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Janji temu disepakati! Pelacakan lokasi aktif pada hari H.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _meetupBusy = false);
    }
  }

  void _openMeetupTracking() {
    final swapId = int.tryParse(widget.matchId);
    if (swapId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetupTrackingPage(
          swapId: swapId,
          partnerName: widget.otherUserName,
          partnerImage: widget.otherUserImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.white.withOpacity(
                0.7,
              ), // Semi-transparent
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                children: [
                  if (widget.otherUserImage != null &&
                      widget.otherUserImage!.isNotEmpty)
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: widget.otherUserImage!.startsWith('http')
                          ? NetworkImage(widget.otherUserImage!)
                          : AssetImage('assets/images/${widget.otherUserImage}')
                                as ImageProvider,
                    )
                  else
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(
                        context,
                      ).primaryColor.withOpacity(0.1),
                      child: Text(
                        widget.otherUserName.isNotEmpty
                            ? widget.otherUserName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.otherUserName,
                          style: AppTextStyles.labelBold.copyWith(
                            color: const Color(0xFF441606),
                          ),
                        ),
                        // Online status placeholder or brief text
                        Text(
                          'Tap for details',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (_meetup != null && !_meetup!.isClosed)
                  IconButton(
                    tooltip: _meetup!.isAgreed
                        ? 'Lacak lokasi janji temu'
                        : 'Atur janji temu',
                    icon: Icon(
                      _meetup!.isTrackingDay()
                          ? Icons.my_location
                          : Icons.event_available_outlined,
                      color: _meetup!.isTrackingDay()
                          ? Colors.green.shade700
                          : AppColors.primary,
                    ),
                    onPressed: _meetup!.isAgreed
                        ? _openMeetupTracking
                        : _openMeetupScheduler,
                  ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.black54),
                  onPressed: () {
                    // TODO: Navigate to trade details/profile
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.background, // Ensure consistent background
        ),
        child: LoadingOverlay(
          isLoading: isLoading,
          child: Column(
            children: [
              // Header spacer
              const SizedBox(height: kToolbarHeight + 20),

              // Meetup ("Janji Temu") Banner
              if (_meetup != null)
                MeetupBanner(
                  meetup: _meetup!,
                  currentUserId: currentUserId,
                  partnerName: widget.otherUserName,
                  busy: _meetupBusy,
                  onPropose: _openMeetupScheduler,
                  onAccept: _acceptMeetup,
                  onTrack: _openMeetupTracking,
                ),

              // Confirm Trade Banner
              if (_shouldShowConfirmTrade())
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ModernCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    backgroundColor: Colors.green.shade50,
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Ready to trade?",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isLoading ? null : _confirmTrade,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text("Confirm"),
                        ),
                      ],
                    ),
                  ),
                ),

              // NEW: Pending Trade Banner (Waiting for partner to confirm)
              if (_isWaitingForPartner())
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: GlassContainer(
                    blurSigma: 10,
                    color: Colors.orange.shade50.withOpacity(0.9),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.4),
                      width: 1.5,
                    ),
                    borderRadius: 12,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        // Pulsing icon to grab attention
                        PulsingIcon(
                          icon: Icons.hourglass_top,
                          color: Colors.orange.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Trade Confirmed!',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Waiting for ${widget.otherUserName} to confirm...',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Chat Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildMessage(messages[index]),
                      ),
                    );
                  },
                ),
              ),

              // Input Area
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: GlassContainer(
        borderRadius: 30,
        blurSigma: 10,
        color: Colors.white.withOpacity(0.9),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
        child: Row(
          children: [
            IconButton(
              onPressed: _showLocationPicker,
              icon: Icon(
                Icons.location_on_outlined,
                color: Theme.of(context).primaryColor,
              ),
              tooltip: 'Share Location',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    const Color(0xFF8B4513),
                  ], // Brand gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  if (_messageController.text.trim().isNotEmpty) {
                    _sendMessage(content: _messageController.text.trim());
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(dynamic message) {
    // Supabase uses 'sender_user_id', old API used 'user_id'
    final senderId =
        message['sender_user_id']?.toString() ?? message['user_id']?.toString();
    final bool isMe = senderId == currentUserId;
    final String messageType = message['type'] ?? 'text';
    final String messageContent =
        message['message_text'] ?? message['content'] ?? '';

    switch (messageType) {
      case 'location':
        return LocationMessageBubble(
          locationName: message['location_name'] ?? '',
          address: message['location_address'] ?? '',
          latitude: message['location_lat']?.toDouble(),
          longitude: message['location_lon']?.toDouble(),
          isMe: isMe,
        );

      case 'location_agreement':
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    messageContent,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        // Modern Chat Bubble
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: isMe
                  ? LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        const Color(0xFF8B4513),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isMe ? null : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: isMe
                    ? const Radius.circular(20)
                    : const Radius.circular(4),
                bottomRight: isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isMe ? 0.2 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              messageContent,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
        );
    }
  }

  /// Check if Confirm Trade button should be shown
  bool _shouldShowConfirmTrade() {
    if (swapData == null) return false;

    final status = swapData?['status'];
    final userAId = swapData?['user_a_id'];
    final isUserA = userAId == currentUserId;
    final bool userConfirmed = isUserA
        ? (swapData?['item_a_owner_confirmed'] == true)
        : (swapData?['item_b_owner_confirmed'] == true);

    // Only show if:
    // 1. Status is active or location_agreed
    // 2. User hasn't confirmed yet
    // 3. Trade not complete
    if (status == 'trade_complete' || userConfirmed) {
      return false;
    }

    if (!['active', 'location_agreed'].contains(status)) {
      return false;
    }

    return true;
  }

  /// NEW: Check if user is waiting for partner to confirm trade
  /// Returns true when current user has confirmed but partner hasn't yet
  bool _isWaitingForPartner() {
    if (swapData == null) return false;

    final status = swapData?['status'];
    // Don't show if trade already complete
    if (status == 'trade_complete') return false;

    final userAId = swapData?['user_a_id'];
    final isUserA = userAId == currentUserId;

    // Get confirmation flags for both users
    final userConfirmed = isUserA
        ? (swapData?['item_a_owner_confirmed'] == true)
        : (swapData?['item_b_owner_confirmed'] == true);

    final partnerConfirmed = isUserA
        ? (swapData?['item_b_owner_confirmed'] == true)
        : (swapData?['item_a_owner_confirmed'] == true);

    // Show banner only when:
    // 1. Current user has confirmed
    // 2. Partner has NOT confirmed yet
    // 3. Status is still active or location_agreed
    return userConfirmed &&
        !partnerConfirmed &&
        ['active', 'location_agreed'].contains(status);
  }

  @override
  void dispose() {
    MeetupService.instance.removeListener(_onMeetupChanged);
    _messageChannel?.unsubscribe();
    _swapChannel?.unsubscribe(); // NEW: Unsubscribe from swap updates
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
