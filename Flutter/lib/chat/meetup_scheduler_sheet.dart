import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trade_match/chat/location_picker_modal.dart';
import 'package:trade_match/models/meetup.dart';
import 'package:trade_match/services/meetup_service.dart';
import 'package:trade_match/theme.dart';

/// Bottom sheet to propose (or reschedule) a meetup: place + date + time.
///
/// Returns `true` via Navigator.pop when the proposal was sent.
class MeetupSchedulerSheet extends StatefulWidget {
  final int swapId;
  final String partnerName;
  final Meetup? existing;

  const MeetupSchedulerSheet({
    super.key,
    required this.swapId,
    required this.partnerName,
    this.existing,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int swapId,
    required String partnerName,
    Meetup? existing,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeetupSchedulerSheet(
        swapId: swapId,
        partnerName: partnerName,
        existing: existing,
      ),
    );
  }

  @override
  State<MeetupSchedulerSheet> createState() => _MeetupSchedulerSheetState();
}

class _MeetupSchedulerSheetState extends State<MeetupSchedulerSheet> {
  String? _placeName;
  String? _placeAddress;
  double? _lat;
  double? _lon;
  DateTime? _date;
  TimeOfDay? _time;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null && e.hasLocation) {
      _placeName = e.name;
      _placeAddress = e.address;
      _lat = e.lat;
      _lon = e.lon;
    }
    if (e?.meetupAt != null && e!.meetupAt!.isAfter(DateTime.now())) {
      _date = DateTime(e.meetupAt!.year, e.meetupAt!.month, e.meetupAt!.day);
      _time = TimeOfDay.fromDateTime(e.meetupAt!);
    }
  }

  DateTime? get _combined => (_date == null || _time == null)
      ? null
      : DateTime(
          _date!.year,
          _date!.month,
          _date!.day,
          _time!.hour,
          _time!.minute,
        );

  bool get _isValid =>
      _lat != null &&
      _lon != null &&
      _combined != null &&
      _combined!.isAfter(DateTime.now());

  Future<void> _pickPlace() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => LocationPickerModal(
        onLocationPicked: (name, address, lat, lng) {
          setState(() {
            _placeName = name;
            _placeAddress = address;
            _lat = lat;
            _lon = lng;
          });
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Pilih tanggal janji temu',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Pilih jam janji temu',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final at = _combined;
    if (_lat == null || _lon == null) {
      _snack('Pilih lokasi pertemuan terlebih dahulu');
      return;
    }
    if (at == null) {
      _snack('Pilih tanggal dan jam janji temu');
      return;
    }
    if (!at.isAfter(DateTime.now())) {
      _snack('Waktu janji temu harus di masa depan');
      return;
    }

    setState(() => _submitting = true);
    try {
      await MeetupService.instance.proposeMeetup(
        swapId: widget.swapId,
        lat: _lat!,
        lon: _lon!,
        name: _placeName ?? 'Lokasi pertemuan',
        address: _placeAddress ?? '',
        meetupAt: at,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack(e.toString());
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isReschedule = widget.existing?.hasSchedule == true;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isReschedule ? 'Ubah Janji Temu' : 'Atur Janji Temu',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 4),
            Text(
              'Tentukan tempat & waktu bertemu dengan ${widget.partnerName}. '
              'Pada hari H, kalian bisa saling melacak lokasi secara real-time.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _OptionTile(
              icon: Icons.place_outlined,
              label: 'Lokasi',
              value: _placeName,
              subtitle: _placeAddress,
              placeholder: 'Pilih titik temu di peta',
              onTap: _submitting ? null : _pickPlace,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _OptionTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'Tanggal',
                    value: _date == null
                        ? null
                        : DateFormat('EEE, d MMM yyyy', 'id_ID').format(_date!),
                    placeholder: 'Pilih',
                    onTap: _submitting ? null : _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OptionTile(
                    icon: Icons.access_time,
                    label: 'Jam',
                    value: _time == null
                        ? null
                        : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
                    placeholder: 'Pilih',
                    onTap: _submitting ? null : _pickTime,
                  ),
                ),
              ],
            ),
            if (_combined != null && !_combined!.isAfter(DateTime.now()))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Waktu yang dipilih sudah lewat.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_submitting || !_isValid) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  _submitting ? 'Mengirim...' : 'Kirim Ajakan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? subtitle;
  final String placeholder;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasValue
              ? AppColors.primary.withOpacity(0.06)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasValue
                ? AppColors.primary.withOpacity(0.4)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? value! : placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelBold.copyWith(
                      color: hasValue
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
