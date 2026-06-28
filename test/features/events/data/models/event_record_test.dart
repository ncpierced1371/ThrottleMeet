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

  test('create serialization includes only shared event fields', () {
    final record = EventRecord(
      id: 'event-1',
      title: 'Test Meet',
      description: 'A test event.',
      locationName: 'Test Garage',
      hostName: 'Test Host',
      startTime: DateTime.utc(2026, 7, 1, 18),
      endTime: DateTime.utc(2026, 7, 1, 20),
      attendeeCount: 7,
      viewerRsvpStatus: RsvpStatus.going,
    );

    final map = record.toCreateMap();

    expect(
      map.keys,
      orderedEquals([
        'id',
        'title',
        'description',
        'location_name',
        'host_name',
        'start_time',
        'end_time',
      ]),
    );
    expect(map.containsKey('attendee_count'), isFalse);
    expect(map.containsKey('rsvp_status'), isFalse);
  });

  test('timestamps serialize to UTC and round-trip as UTC', () {
    final startTime = DateTime.parse('2026-07-01T18:00:00-07:00');
    final endTime = DateTime.parse('2026-07-01T20:00:00-07:00');
    final record = EventRecord(
      id: 'event-1',
      title: 'Test Meet',
      description: 'A test event.',
      locationName: 'Test Garage',
      hostName: 'Test Host',
      startTime: startTime,
      endTime: endTime,
      attendeeCount: 0,
      viewerRsvpStatus: null,
    );

    final createMap = record.toCreateMap();
    final roundTrippedRecord = EventRecord.fromMap({
      ...createMap,
      'attendee_count': 0,
      'rsvp_status': null,
    });

    expect(createMap['start_time'], '2026-07-02T01:00:00.000Z');
    expect(createMap['end_time'], '2026-07-02T03:00:00.000Z');
    expect(roundTrippedRecord.startTime, startTime.toUtc());
    expect(roundTrippedRecord.endTime, endTime.toUtc());
    expect(roundTrippedRecord.startTime.isUtc, isTrue);
    expect(roundTrippedRecord.endTime.isUtc, isTrue);
  });

  test('invalid Supabase timestamps throw a field-specific error', () {
    expect(
      () => EventRecord.fromMap({
        'id': 'event-1',
        'title': 'Test Meet',
        'description': 'A test event.',
        'location_name': 'Test Garage',
        'host_name': 'Test Host',
        'start_time': 'not-a-timestamp',
        'end_time': '2026-07-01T20:00:00Z',
        'attendee_count': 0,
        'rsvp_status': null,
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('start_time'),
        ),
      ),
    );
  });
}
