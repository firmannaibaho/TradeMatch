import 'package:latlong2/latlong.dart';

/// Meetup ("Janji Temu") information stored on a swap row.
///
/// Status flow on `swaps.status`:
///   active -> location_suggested (proposal sent) -> location_agreed (accepted)
class Meetup {
  final int swapId;
  final String status;
  final double? lat;
  final double? lon;
  final String? name;
  final String? address;
  final DateTime? meetupAt; // local time
  final String? suggestedBy;
  final String? userAId;
  final String? userBId;

  const Meetup({
    required this.swapId,
    required this.status,
    this.lat,
    this.lon,
    this.name,
    this.address,
    this.meetupAt,
    this.suggestedBy,
    this.userAId,
    this.userBId,
  });

  factory Meetup.fromSwap(Map<String, dynamic> swap) {
    double? toDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());

    final rawAt = swap['meetup_at'];
    return Meetup(
      swapId: int.tryParse(swap['id'].toString()) ?? 0,
      status: (swap['status'] ?? 'active').toString(),
      lat: toDouble(swap['suggested_location_lat']),
      lon: toDouble(swap['suggested_location_lon']),
      name: swap['suggested_location_name']?.toString(),
      address: swap['suggested_location_address']?.toString(),
      meetupAt: rawAt == null
          ? null
          : DateTime.tryParse(rawAt.toString())?.toLocal(),
      suggestedBy: swap['location_suggested_by']?.toString(),
      userAId: swap['user_a_id']?.toString(),
      userBId: swap['user_b_id']?.toString(),
    );
  }

  bool get hasLocation => lat != null && lon != null;
  LatLng? get point => hasLocation ? LatLng(lat!, lon!) : null;

  bool get hasSchedule => meetupAt != null && hasLocation;
  bool get isProposed => status == 'location_suggested' && hasSchedule;
  bool get isAgreed => status == 'location_agreed' && hasSchedule;
  bool get isClosed => status == 'trade_complete' || status == 'cancelled';

  /// Swap statuses in which a (new) meetup proposal can be made.
  bool get canPropose =>
      ['active', 'location_suggested', 'location_agreed'].contains(status);

  bool proposedByMe(String? myUserId) =>
      suggestedBy != null && suggestedBy == myUserId;

  String? partnerId(String? myUserId) =>
      userAId == myUserId ? userBId : userAId;

  /// Live tracking is available on the meetup's calendar day (device local time).
  bool isTrackingDay([DateTime? now]) {
    if (!isAgreed) return false;
    final n = now ?? DateTime.now();
    final m = meetupAt!;
    return n.year == m.year && n.month == m.month && n.day == m.day;
  }

  /// The meetup day is already over (local time).
  bool isPast([DateTime? now]) {
    if (meetupAt == null) return false;
    final n = now ?? DateTime.now();
    final endOfDay = DateTime(meetupAt!.year, meetupAt!.month, meetupAt!.day)
        .add(const Duration(days: 1));
    return !n.isBefore(endOfDay);
  }
}

/// A participant's last known live position for a meetup.
class LiveLocation {
  final int swapId;
  final String userId;
  final double lat;
  final double lon;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final bool isSharing;
  final DateTime updatedAt;

  const LiveLocation({
    required this.swapId,
    required this.userId,
    required this.lat,
    required this.lon,
    this.accuracy,
    this.heading,
    this.speed,
    required this.isSharing,
    required this.updatedAt,
  });

  LatLng get point => LatLng(lat, lon);

  factory LiveLocation.fromMap(Map<String, dynamic> m) {
    double? d(dynamic v) => v == null ? null : double.tryParse(v.toString());
    return LiveLocation(
      swapId: int.tryParse(m['swap_id'].toString()) ?? 0,
      userId: m['user_id'].toString(),
      lat: d(m['lat']) ?? 0,
      lon: d(m['lon']) ?? 0,
      accuracy: d(m['accuracy']),
      heading: d(m['heading']),
      speed: d(m['speed']),
      isSharing: m['is_sharing'] == true,
      updatedAt:
          DateTime.tryParse(m['updated_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}
