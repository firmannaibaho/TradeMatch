import 'package:flutter/material.dart';
import 'package:trade_match/theme.dart';

/// Match Success Dialog - Shows celebration when users match
/// Displays both items and provides options to chat or continue swiping
class MatchSuccessDialog extends StatefulWidget {
  final String otherUserName;
  final String? otherUserImage;
  final String myItemTitle;
  final String theirItemTitle;
  final String swapId;
  final VoidCallback onKeepSwiping;
  final Function(String swapId, String otherUserName, String? otherUserImage)
  onStartChat;

  const MatchSuccessDialog({
    super.key,
    required this.otherUserName,
    this.otherUserImage,
    required this.myItemTitle,
    required this.theirItemTitle,
    required this.swapId,
    required this.onKeepSwiping,
    required this.onStartChat,
  });

  @override
  State<MatchSuccessDialog> createState() => _MatchSuccessDialogState();
}

class _MatchSuccessDialogState extends State<MatchSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration Icon
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.favorite, size: 40, color: primary),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                "It's a Match!",
                style: AppTextStyles.heading2.copyWith(
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'You and ${widget.otherUserName} liked each other!',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // Trade Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // My Item
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.swap_horiz, color: primary, size: 20),
                          const SizedBox(height: 8),
                          Text(
                            widget.myItemTitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Arrow
                    Icon(Icons.compare_arrows, color: primary, size: 32),

                    // Their Item
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.swap_horiz, color: primary, size: 20),
                          const SizedBox(height: 8),
                          Text(
                            widget.theirItemTitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  // Keep Swiping Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onKeepSwiping,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Keep Swiping',
                        style: TextStyle(color: primary),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Start Chatting Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onStartChat(
                          widget.swapId,
                          widget.otherUserName,
                          widget.otherUserImage,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Start Chatting',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
