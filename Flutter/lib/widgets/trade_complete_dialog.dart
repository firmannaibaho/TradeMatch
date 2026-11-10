import 'package:flutter/material.dart';
import 'package:trade_match/theme.dart';

/// Trade Complete Dialog - Shown when both users confirm trade
/// Celebrates completion and prompts for review
class TradeCompleteDialog extends StatelessWidget {
  final VoidCallback onLeaveReview;
  final VoidCallback onClose;

  const TradeCompleteDialog({
    super.key,
    required this.onLeaveReview,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
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
            // Success Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 50,
                color: Colors.green,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              'Trade Complete!',
              style: AppTextStyles.heading2.copyWith(
                color: primary,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Message
            Text(
              'Both parties have confirmed the trade. Don\'t forget to leave a review!',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                // Maybe Later Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Maybe Later',
                      style: TextStyle(color: primary),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Leave Review Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: onLeaveReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Leave Review',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
