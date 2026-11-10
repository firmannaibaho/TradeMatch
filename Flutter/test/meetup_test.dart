import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trade_match/models/meetup.dart';
import 'package:trade_match/services/meetup_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('Meetup model', () {
    test('parses swap map and detects tracking day accurately', () {
      final nowLocal = DateTime(2026, 10, 26, 14, 30);
      final meetupLocal = DateTime(2026, 10, 26, 17, 0);

      final meetup = Meetup.fromSwap({
        'id': 42,
        'status': 'location_agreed',
        'suggested_location_lat': -6.200000,
        'suggested_location_lon': 106.816666,
        'suggested_location_name': 'Grand Indonesia',
        'suggested_location_address': 'Jl. M.H. Thamrin No.1, Jakarta',
        'meetup_at': meetupLocal.toUtc().toIso8601String(),
        'location_suggested_by': 'user-a',
        'user_a_id': 'user-a',
        'user_b_id': 'user-b',
      });

      expect(meetup.swapId, 42);
      expect(meetup.hasLocation, isTrue);
      expect(meetup.hasSchedule, isTrue);
      expect(meetup.isAgreed, isTrue);
      expect(meetup.isProposed, isFalse);
      expect(meetup.proposedByMe('user-a'), isTrue);
      expect(meetup.proposedByMe('user-b'), isFalse);
      expect(meetup.partnerId('user-a'), 'user-b');
      expect(meetup.partnerId('user-b'), 'user-a');

      // Same calendar day -> tracking day is true
      expect(meetup.isTrackingDay(nowLocal), isTrue);

      // Day before -> not tracking day, not past
      final dayBefore = DateTime(2026, 10, 25, 23, 59);
      expect(meetup.isTrackingDay(dayBefore), isFalse);
      expect(meetup.isPast(dayBefore), isFalse);

      // Day after -> not tracking day, is past
      final dayAfter = DateTime(2026, 10, 27, 0, 1);
      expect(meetup.isTrackingDay(dayAfter), isFalse);
      expect(meetup.isPast(dayAfter), isTrue);
    });

    test('isTrackingDay is false when status is only location_suggested', () {
      final today = DateTime(2026, 10, 26, 10, 0);
      final meetup = Meetup.fromSwap({
        'id': 7,
        'status': 'location_suggested',
        'suggested_location_lat': 3.5952,
        'suggested_location_lon': 98.6722,
        'suggested_location_name': 'Merdeka Walk',
        'meetup_at': today.toUtc().toIso8601String(),
      });

      expect(meetup.isProposed, isTrue);
      expect(meetup.isAgreed, isFalse);
      expect(meetup.isTrackingDay(today), isFalse);
    });

    test('formats Indonesian meetup date/time label', () {
      final dt = DateTime(2026, 10, 26, 15, 5);
      final formatted = MeetupService.formatMeetupLabel(dt);
      expect(formatted, contains('2026'));
      expect(formatted, contains('15:05'));
    });
  });

  group('LiveLocation model', () {
    test('parses live location row', () {
      final loc = LiveLocation.fromMap({
        'swap_id': 42,
        'user_id': 'user-b',
        'lat': -6.201,
        'lon': 106.817,
        'accuracy': 8.5,
        'heading': 90.0,
        'speed': 1.2,
        'is_sharing': true,
        'updated_at': '2026-10-26T10:00:00Z',
      });

      expect(loc.swapId, 42);
      expect(loc.userId, 'user-b');
      expect(loc.point.latitude, closeTo(-6.201, 1e-6));
      expect(loc.point.longitude, closeTo(106.817, 1e-6));
      expect(loc.accuracy, 8.5);
      expect(loc.isSharing, isTrue);
    });
  });
}
