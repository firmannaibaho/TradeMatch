import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trade_match/models/meetup.dart';
import 'package:trade_match/services/meetup_service.dart';
import 'package:trade_match/services/supabase_service.dart';
import 'package:trade_match/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Live map for a meetup: shows the meeting point, my position and the
/// partner's live position (via Supabase Realtime), and lets me start/stop
/// sharing my own location on the meetup day.
class MeetupTrackingPage extends StatefulWidget {
  final int swapId;
  final String partnerName;
  final String? partnerImage;

  const MeetupTrackingPage({
    super.key,
    required this.swapId,
    required this.partnerName,
    this.partnerImage,
  });

  @override
  State<MeetupTrackingPage> createState() => _MeetupTrackingPageState();
}

class _MeetupTrackingPageState extends State<MeetupTrackingPage> {
  /// After this long without an update the partner is shown as "offline".
  static const Duration _staleAfter = Duration(minutes: 2);

  final MapController _mapController = MapController();
  final MeetupService _meetupService = MeetupService.instance;
  final Distance _distance = const Distance();

  Meetup? _meetup;
  LiveLocation? _partnerLocation;
  LiveLocation? _myServerLocation;
  RealtimeChannel? _liveChannel;
  RealtimeChannel? _swapChannel;
  Timer? _ticker;
  bool _loading = true;
  bool _toggling = false;
  bool _mapReady = false;
  bool _autoFitted = false;
  String? _loadError;

  String? get _myId => SupabaseService().userId;

  @override
  void initState() {
    super.initState();
    _meetupService.addListener(_onServiceChanged);
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {}); // refresh "x seconds ago" labels
    });
    _load();
  }

  @override
  void dispose() {
    _meetupService.removeListener(_onServiceChanged);
    _liveChannel?.unsubscribe();
    _swapChannel?.unsubscribe();
    _ticker?.cancel();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {});
    final err = _meetupService.lastError;
    if (err != null && !_meetupService.isSharing(widget.swapId)) {
      // Sharing was stopped by the service (e.g. window closed).
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _load() async {
    try {
      final swap = await SupabaseService().getSwap(widget.swapId);
      final locations = await _meetupService.fetchLiveLocations(widget.swapId);
      if (!mounted) return;
      setState(() {
        _meetup = Meetup.fromSwap(swap);
        for (final l in locations) {
          _applyLocation(l);
        }
        _loading = false;
      });
      _subscribe();
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Gagal memuat data janji temu: $e';
      });
    }
  }

  void _subscribe() {
    _liveChannel = _meetupService.subscribeLiveLocations(widget.swapId, (loc) {
      if (!mounted) return;
      final firstPartnerFix =
          _partnerLocation == null && loc.userId != _myId && loc.isSharing;
      setState(() => _applyLocation(loc));
      if (firstPartnerFix) _fitAll();
    });

    _swapChannel = Supabase.instance.client
        .channel('meetup_swap:${widget.swapId}:${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'swaps',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.swapId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final updated = Meetup.fromSwap(payload.newRecord);
            setState(() => _meetup = updated);
            if (!updated.isAgreed &&
                _meetupService.isSharing(widget.swapId)) {
              _meetupService.stopSharing(updateServer: false);
            }
          },
        )
        .subscribe();
  }

  void _applyLocation(LiveLocation loc) {
    if (loc.userId == _myId) {
      _myServerLocation = loc;
    } else {
      _partnerLocation = loc;
    }
  }

  // ----------------------------------------------------------
  // Derived state
  // ----------------------------------------------------------

  bool get _isSharing => _meetupService.isSharing(widget.swapId);

  LatLng? get _myPoint {
    final p = _isSharing ? _meetupService.lastPosition : null;
    if (p != null) return LatLng(p.latitude, p.longitude);
    if (_myServerLocation?.isSharing == true) return _myServerLocation!.point;
    return null;
  }

  bool get _partnerVisible => _partnerLocation != null;

  bool get _partnerLive =>
      _partnerLocation != null &&
      _partnerLocation!.isSharing &&
      DateTime.now().difference(_partnerLocation!.updatedAt) < _staleAfter;

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 10) return 'baru saja';
    if (d.inSeconds < 60) return '${d.inSeconds} dtk lalu';
    if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
    if (d.inHours < 24) return '${d.inHours} jam lalu';
    return '${d.inDays} hari lalu';
  }

  String _fmtDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  double? _meters(LatLng? a, LatLng? b) {
    if (a == null || b == null) return null;
    return _distance.as(LengthUnit.Meter, a, b);
  }

  // ----------------------------------------------------------
  // Actions
  // ----------------------------------------------------------

  void _fitAll() {
    if (!_mapReady || !mounted) return;
    final pts = <LatLng>[
      if (_meetup?.point != null) _meetup!.point!,
      if (_myPoint != null) _myPoint!,
      if (_partnerVisible) _partnerLocation!.point,
    ];
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _mapController.move(pts.first, 16);
    } else {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.fromLTRB(60, 120, 60, 300),
          maxZoom: 17,
        ),
      );
    }
    _autoFitted = true;
  }

  Future<void> _toggleSharing(bool enable) async {
    setState(() => _toggling = true);
    try {
      if (enable) {
        await _meetupService.startSharing(widget.swapId);
        if (!_autoFitted || _partnerVisible) _fitAll();
      } else {
        await _meetupService.stopSharing();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _openDirections() async {
    final p = _meetup?.point;
    if (p == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lacak Janji Temu', style: TextStyle(fontSize: 17)),
            Text(
              'dengan ${widget.partnerName}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Pusatkan peta',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _fitAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : Stack(
              children: [
                _buildMap(),
                Positioned(left: 0, right: 0, bottom: 0, child: _buildPanel()),
              ],
            ),
    );
  }

  Widget _buildMap() {
    final meetPoint = _meetup?.point;
    final me = _myPoint;
    final partner = _partnerVisible ? _partnerLocation!.point : null;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: meetPoint ?? me ?? const LatLng(-6.2, 106.816666),
        initialZoom: 15,
        onMapReady: () {
          _mapReady = true;
          _fitAll();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.project',
        ),
        if (meetPoint != null)
          PolylineLayer(
            polylines: [
              if (partner != null)
                Polyline(
                  points: [partner, meetPoint],
                  color: AppColors.primary.withOpacity(0.7),
                  strokeWidth: 3,
                  isDotted: true,
                ),
              if (me != null)
                Polyline(
                  points: [me, meetPoint],
                  color: Colors.blue.withOpacity(0.6),
                  strokeWidth: 3,
                  isDotted: true,
                ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (meetPoint != null)
              Marker(
                point: meetPoint,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 44,
                ),
              ),
            if (partner != null)
              Marker(
                point: partner,
                width: 54,
                height: 54,
                child: _PersonMarker(
                  label: widget.partnerName,
                  imageUrl: widget.partnerImage,
                  color: _partnerLive ? AppColors.primary : Colors.grey,
                ),
              ),
            if (me != null)
              Marker(
                point: me,
                width: 26,
                height: 26,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  Widget _buildPanel() {
    final meetup = _meetup!;
    final trackingDay = meetup.isTrackingDay();
    final meetPoint = meetup.point;
    final partnerDist = _partnerVisible
        ? _meters(_partnerLocation!.point, meetPoint)
        : null;
    final myDist = _meters(_myPoint, meetPoint);
    final betweenUs = _partnerVisible
        ? _meters(_myPoint, _partnerLocation!.point)
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Meeting point
            Row(
              children: [
                const Icon(Icons.location_pin, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meetup.name ?? 'Lokasi pertemuan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelBold,
                      ),
                      if (meetup.meetupAt != null)
                        Text(
                          MeetupService.formatMeetupLabel(meetup.meetupAt!),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _openDirections,
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Rute'),
                ),
              ],
            ),
            const Divider(height: 20),

            // Partner status
            _StatusRow(
              color: _partnerLive ? AppColors.primary : Colors.grey,
              icon: Icons.person_pin_circle,
              title: !_partnerVisible
                  ? '${widget.partnerName} belum membagikan lokasi'
                  : _partnerLive
                  ? '${widget.partnerName} sedang dalam perjalanan'
                  : '${widget.partnerName} berhenti berbagi lokasi',
              subtitle: !_partnerVisible
                  ? 'Lokasi akan muncul di peta saat partner mulai berbagi.'
                  : [
                      if (partnerDist != null)
                        '${_fmtDistance(partnerDist)} dari titik temu',
                      if (betweenUs != null)
                        '${_fmtDistance(betweenUs)} darimu',
                      'diperbarui ${_ago(_partnerLocation!.updatedAt)}',
                    ].join(' • '),
            ),
            const SizedBox(height: 10),

            // My status
            _StatusRow(
              color: _isSharing ? Colors.blue : Colors.grey,
              icon: Icons.my_location,
              title: _isSharing
                  ? 'Lokasimu dibagikan secara real-time'
                  : 'Lokasimu tidak dibagikan',
              subtitle: _isSharing
                  ? [
                      if (myDist != null)
                        '${_fmtDistance(myDist)} dari titik temu',
                      if (_meetupService.lastError != null)
                        _meetupService.lastError!,
                    ].join(' • ')
                  : trackingDay
                  ? 'Aktifkan agar ${widget.partnerName} bisa melihat posisimu.'
                  : meetup.isAgreed
                  ? 'Pelacakan hanya tersedia pada hari janji temu.'
                  : 'Janji temu belum disepakati kedua pihak.',
            ),
            const SizedBox(height: 14),

            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (_toggling || (!trackingDay && !_isSharing))
                    ? null
                    : () => _toggleSharing(!_isSharing),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSharing
                      ? Colors.red.shade400
                      : Colors.green.shade600,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _toggling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isSharing ? Icons.location_off : Icons.share_location,
                        color: Colors.white,
                      ),
                label: Text(
                  _isSharing ? 'Berhenti Berbagi Lokasi' : 'Bagikan Lokasi Saya',
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

class _StatusRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  const _StatusRow({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelBold),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonMarker extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final Color color;

  const _PersonMarker({
    required this.label,
    required this.color,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.startsWith('http');
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: CircleAvatar(
        backgroundColor: color,
        backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
        child: hasImage
            ? null
            : Text(
                label.isNotEmpty ? label[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
      ),
    );
  }
}
