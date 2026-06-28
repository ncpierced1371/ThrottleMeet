import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/features/events/data/models/event_record.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/rsvp_status.dart';

void main() {
  test('maps a null viewer RSVP without changing attendee count', () {
    final event = EventRecord.fromMap({
      'id': 'event-1',
      'title': 'Test Meet',
      'description': 'A test event.',
      'location_name': 'Test Garage',
      'host_name': 'Test Host',
      'start_time': '2026-07-01T18:00:00Z',
      'end_time': '2026-07-01T20:00:00Z',
      'attendee_count': 7,
      'rsvp_status': null,
    }).toEntity();

    expect(event.viewerRsvpStatus, isNull);
    expect(event.attendeeCount, 7);
  });

  test('maps an existing viewer RSVP', () {
    final event = EventRecord.fromMap({
      'id': 'event-1',
      'title': 'Test Meet',
      'description': 'A test event.',
      'location_name': 'Test Garage',
      'host_name': 'Test Host',
      'start_time': '2026-07-01T18:00:00Z',
      'end_time': '2026-07-01T20:00:00Z',
      'attendee_count': 7,
      'rsvp_status': 'going',
    }).toEntity();

    expect(event.viewerRsvpStatus, RsvpStatus.going);
    expect(event.attendeeCount, 7);
  });

  test('copyWith can explicitly clear the viewer RSVP', () {
    final event = EventRecord.fromMap({
      'id': 'event-1',
      'title': 'Test Meet',
      'description': 'A test event.',
      'location_name': 'Test Garage',
      'host_name': 'Test Host',
      'start_time': '2026-07-01T18:00:00Z',
      'end_time': '2026-07-01T20:00:00Z',
      'attendee_count': 7,
      'rsvp_status': 'interested',
    }).toEntity();

    final updatedEvent = event.copyWith(viewerRsvpStatus: null);

    expect(updatedEvent.viewerRsvpStatus, isNull);
    expect(updatedEvent.attendeeCount, 7);
  });
}
