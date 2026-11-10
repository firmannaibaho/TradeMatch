import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trade_match/models/meetup.dart';

/// Thrown for user-facing meetup / tracking errors.
class MeetupException implements Exception {
  final String message;
  const MeetupException(this.message);
  @override
  String toString() => message;
}

/// Handles "Janji Temu" (meetup) scheduling and live location sharing.
///
/// Live sharing is a singleton concern: only one meetup can be shared at a
/// time and it keeps running while the user navigates around the app (on
/// Android a foreground-service notification keeps GPS alive when the app
/// is in the background).
class MeetupService extends ChangeNotifier {
  MeetupService._();
  static final MeetupService instance = MeetupService._();

  static const String table = 'meetup_live_locations';

  /// Minimum interval between two uploads of our position.
  static const Duration _minUploadInterval = Duration(seconds: 3);

  /// Re-send the last position periodically so the partner can see we are
  /// still online even when standing still.
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  int? _sharingSwapId;
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeat;
  Timer? _pendingUpload;
  DateTime? _lastUploadAt;
  Position? _lastPosition;
  String? _lastError;

  int? get sharingSwapId => _sharingSwapId;
  bool isSharing(int swapId) => _sharingSwapId == swapId;
  Position? get lastPosition => _lastPosition;
  String? get lastError => _lastError;

  // ==========================================================
  // SCHEDULING (edge functions)
  // ==========================================================

  static String formatMeetupLabel(DateTime local) =>
      DateFormat('EEEE, d MMM yyyy • HH:mm', 'id_ID').format(local);

  /// Propose (or reschedule) a meetup place + date/time to the partner.
  Future<void> proposeMeetup({
    required int swapId,
    required double lat,
    required double lon,
    required String name,
    required String address,
    required DateTime meetupAt,
  }) async {
    final response = await _client.functions.invoke(
      'suggest-location',
      body: {
        'swap_id': swapId,
        'location_lat': lat,
        'location_lon': lon,
        'location_name': name.length > 255 ? name.substring(0, 255) : name,
        'location_address':
            address.length > 500 ? address.substring(0, 500) : address,
        'meetup_at': meetupAt.toUtc().toIso8601String(),
        'meetup_label': formatMeetupLabel(meetupAt),
      },
    );
    if (response.status != 200) {
      throw MeetupException(
        _errorFrom(response.data) ?? 'Gagal mengirim ajakan janji temu',
      );
    }
    // Any running share for this swap is invalidated server-side.
    if (isSharing(swapId)) await stopSharing(updateServer: false);
  }

  /// Accept the partner's meetup proposal.
  Future<void> acceptMeetup(int swapId) async {
    final response = await _client.functions.invoke(
      'accept-location',
      body: {'swap_id': swapId},
    );
    if (response.status != 200) {
      throw MeetupException(
        _errorFrom(response.data) ?? 'Gagal menerima janji temu',
      );
    }
  }

  String? _errorFrom(dynamic data) {
    if (data is Map && data['error'] != null) return data['error'].toString();
    return null;
  }

  // ==========================================================
  // READING PARTNER LOCATION
  // ==========================================================

  Future<List<LiveLocation>> fetchLiveLocations(int swapId) async {
    final rows = await _client.from(table).select().eq('swap_id', swapId);
    return (rows as List)
        .map((r) => LiveLocation.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Subscribe to live location inserts/updates for a swap.
  RealtimeChannel subscribeLiveLocations(
    int swapId,
    void Function(LiveLocation location) onChange,
  ) {
    return _client
        .channel('meetup_live:$swapId:${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'swap_id',
            value: swapId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return; // DELETE events carry no new record
            onChange(LiveLocation.fromMap(record));
          },
        )
        .subscribe();
  }

  // ==========================================================
  // SHARING MY LOCATION
  // ==========================================================

  /// Ensures GPS is on and location permission is granted.
  Future<void> ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const MeetupException(
        'GPS tidak aktif. Aktifkan layanan lokasi terlebih dahulu.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const MeetupException('Izin lokasi ditolak.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const MeetupException(
        'Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.',
      );
    }
  }

  /// Start sharing my live location for [swapId].
  ///
  /// Throws [MeetupException] if permission is missing or the server rejects
  /// the share (e.g. it is not the meetup day / meetup not agreed).
  Future<void> startSharing(int swapId) async {
    if (_userId == null) throw const MeetupException('Belum login.');
    if (isSharing(swapId)) return;

    await ensureLocationPermission();
    if (_sharingSwapId != null) await stopSharing();

    _lastError = null;

    // Push a first fix right away so an RLS rejection surfaces immediately.
    final first = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(const Duration(seconds: 20));
    try {
      await _upload(swapId, first);
    } on PostgrestException catch (e) {
      throw MeetupException(_describePostgrest(e));
    }

    _sharingSwapId = swapId;
    _lastPosition = first;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen(
      (pos) => _onPosition(swapId, pos),
      onError: (Object e) {
        debugPrint('❌ [MEETUP] Position stream error: $e');
        _lastError = 'Gagal membaca GPS: $e';
        notifyListeners();
      },
    );

    _heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      final p = _lastPosition;
      if (p != null && _sharingSwapId == swapId) _safeUpload(swapId, p);
    });

    notifyListeners();
  }

  /// Stop sharing. The partner will see that sharing has stopped.
  Future<void> stopSharing({bool updateServer = true}) async {
    final swapId = _sharingSwapId;
    await _positionSub?.cancel();
    _positionSub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _pendingUpload?.cancel();
    _pendingUpload = null;
    _sharingSwapId = null;
    _lastUploadAt = null;
    notifyListeners();

    if (updateServer && swapId != null && _userId != null) {
      try {
        await _client
            .from(table)
            .update({'is_sharing': false})
            .eq('swap_id', swapId)
            .eq('user_id', _userId!);
      } catch (e) {
        debugPrint('⚠️ [MEETUP] Failed to mark sharing stopped: $e');
      }
    }
  }

  LocationSettings _buildLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Berbagi lokasi janji temu',
          notificationText:
              'TradeMatch sedang membagikan lokasimu ke partner barter.',
          notificationChannelName: 'Pelacakan Janji Temu',
          enableWakeLock: true,
          setOngoing: true,
          color: Color(0xFFFD7E14),
        ),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        activityType: ActivityType.otherNavigation,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  void _onPosition(int swapId, Position pos) {
    if (_sharingSwapId != swapId) return;
    _lastPosition = pos;
    notifyListeners();

    final now = DateTime.now();
    final since = _lastUploadAt == null
        ? _minUploadInterval
        : now.difference(_lastUploadAt!);

    if (since >= _minUploadInterval) {
      _pendingUpload?.cancel();
      _pendingUpload = null;
      _safeUpload(swapId, pos);
    } else {
      // Coalesce bursts: upload the latest fix when the interval elapses.
      _pendingUpload ??= Timer(_minUploadInterval - since, () {
        _pendingUpload = null;
        final latest = _lastPosition;
        if (latest != null && _sharingSwapId == swapId) {
          _safeUpload(swapId, latest);
        }
      });
    }
  }

  Future<void> _safeUpload(int swapId, Position pos) async {
    try {
      await _upload(swapId, pos);
      if (_lastError != null) {
        _lastError = null;
        notifyListeners();
      }
    } on PostgrestException catch (e) {
      debugPrint('❌ [MEETUP] Upload rejected: ${e.code} ${e.message}');
      _lastError = _describePostgrest(e);
      // Permission/RLS failure => window closed or meetup changed: stop.
      if (e.code == '42501') {
        await stopSharing(updateServer: false);
      } else {
        notifyListeners();
      }
    } catch (e) {
      // Network hiccup: keep the stream running, next fix will retry.
      debugPrint('⚠️ [MEETUP] Upload failed (will retry): $e');
      _lastError = 'Koneksi bermasalah, mencoba lagi...';
      notifyListeners();
    }
  }

  Future<void> _upload(int swapId, Position pos) async {
    _lastUploadAt = DateTime.now();
    await _client.from(table).upsert({
      'swap_id': swapId,
      'user_id': _userId,
      'lat': pos.latitude,
      'lon': pos.longitude,
      'accuracy': pos.accuracy,
      'heading': pos.heading,
      'speed': pos.speed,
      'is_sharing': true,
    }, onConflict: 'swap_id,user_id');
  }

  String _describePostgrest(PostgrestException e) {
    if (e.code == '42501') {
      return 'Pelacakan hanya bisa dilakukan pada hari janji temu yang sudah disepakati.';
    }
    return 'Gagal membagikan lokasi: ${e.message}';
  }
}
