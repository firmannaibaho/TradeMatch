import 'package:flutter/material.dart';
import 'package:trade_match/models/meetup.dart';
import 'package:trade_match/services/meetup_service.dart';
import 'package:trade_match/theme.dart';

/// Card shown at the top of a chat describing the meetup ("Janji Temu")
/// state and offering the relevant action (propose / accept / track).
class MeetupBanner extends StatelessWidget {
  final Meetup meetup;
  final String? currentUserId;
  final String partnerName;
  final bool busy;
  final VoidCallback onPropose;
  final VoidCallback onAccept;
  final VoidCallback onTrack;

  const MeetupBanner({
    super.key,
    required this.meetup,
    required this.currentUserId,
    required this.partnerName,
    required this.onPropose,
    required this.onAccept,
    required this.onTrack,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    if (meetup.isClosed) return const SizedBox.shrink();

    // No meetup scheduled yet → compact call-to-action
    if (!meetup.hasSchedule ||
        !(meetup.isProposed || meetup.isAgreed)) {
      return _card(
        color: Colors.white,
        borderColor: AppColors.divider,
        icon: Icons.event_available_outlined,
        iconColor: AppColors.primary,
        title: 'Belum ada janji temu',
        subtitle: 'Atur tempat & waktu bertemu untuk barter.',
        actions: [_primaryButton('Atur', onPropose)],
      );
    }

    final label = MeetupService.formatMeetupLabel(meetup.meetupAt!);
    final place = meetup.name ?? 'Lokasi pertemuan';

    if (meetup.isProposed) {
      final mine = meetup.proposedByMe(currentUserId);
      return _card(
        color: Colors.amber.shade50,
        borderColor: Colors.amber.shade200,
        icon: Icons.schedule_send_outlined,
        iconColor: Colors.amber.shade800,
        title: mine
            ? 'Menunggu $partnerName menyetujui'
            : '$partnerName mengajak janji temu',
        subtitle: '$place\n$label',
        actions: mine
            ? [_textButton('Ubah', onPropose)]
            : [
                _textButton('Ubah', onPropose),
                _primaryButton('Terima', onAccept),
              ],
      );
    }

    // Agreed
    if (meetup.isTrackingDay()) {
      final sharing = MeetupService.instance.isSharing(meetup.swapId);
      return _card(
        color: Colors.green.shade50,
        borderColor: Colors.green.shade200,
        icon: sharing ? Icons.share_location : Icons.my_location,
        iconColor: Colors.green.shade700,
        title: sharing
            ? 'Lokasimu sedang dibagikan'
            : 'Hari ini janji temu!',
        subtitle: '$place\n$label',
        actions: [
          _primaryButton(
            sharing ? 'Buka Peta' : 'Lacak',
            onTrack,
            color: Colors.green.shade600,
          ),
        ],
      );
    }

    final past = meetup.isPast();
    return _card(
      color: past ? Colors.grey.shade100 : Colors.blue.shade50,
      borderColor: past ? Colors.grey.shade300 : Colors.blue.shade100,
      icon: past ? Icons.event_busy_outlined : Icons.event_available,
      iconColor: past ? Colors.grey.shade600 : Colors.blue.shade700,
      title: past ? 'Janji temu sudah lewat' : 'Janji temu disepakati',
      subtitle: past
          ? '$place\n$label'
          : '$place\n$label\nPelacakan lokasi aktif di hari H.',
      actions: [
        _textButton(past ? 'Atur Ulang' : 'Ubah', onPropose),
        if (!past) _textButton('Peta', onTrack),
      ],
    );
  }

  Widget _card({
    required Color color,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: actions,
              ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton(String text, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _textButton(String text, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
