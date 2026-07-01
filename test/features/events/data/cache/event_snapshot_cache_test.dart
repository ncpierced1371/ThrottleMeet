import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttlemeet_v2/src/features/events/data/cache/event_snapshot_cache.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/event.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/event_snapshot.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/rsvp_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('snapshots are authenticated-user-specific', () async {
    final cache = SharedPreferencesEventSnapshotCache();
    final userACachedAt = DateTime.utc(2026, 6, 28, 12);
    final userBCachedAt = DateTime.utc(2026, 6, 28, 13);

    await cache.write(
      'user-a',
      EventSnapshot(
        events: [_event(id: 'event-a', viewerRsvpStatus: RsvpStatus.going)],
        cachedAt: userACachedAt,
      ),
    );
    await cache.write(
      'user-b',
      EventSnapshot(
        events: [
          _event(id: 'event-b', viewerRsvpStatus: RsvpStatus.interested),
        ],
        cachedAt: userBCachedAt,
      ),
    );

    final userA = await cache.read('user-a');
    final userB = await cache.read('user-b');
    final userC = await cache.read('user-c');

    expect(userA?.events.single.id, 'event-a');
    expect(userA?.events.single.viewerRsvpStatus, RsvpStatus.going);
    expect(userA?.cachedAt, userACachedAt);
    expect(userB?.events.single.id, 'event-b');
    expect(userB?.events.single.viewerRsvpStatus, RsvpStatus.interested);
    expect(userB?.cachedAt, userBCachedAt);
    expect(userC, isNull);
  });

  test('nullable RSVP status and attendee count round-trip', () async {
    final cache = SharedPreferencesEventSnapshotCache();
    final cachedAt = DateTime.parse('2026-06-28T12:00:00-07:00');
    final event = _event(
      id: 'event-without-rsvp',
      viewerRsvpStatus: null,
      attendeeCount: 9,
    );

    await cache.write(
      'user-a',
      EventSnapshot(events: [event], cachedAt: cachedAt),
    );
    final snapshot = await cache.read('user-a');

    expect(snapshot?.events.single.viewerRsvpStatus, isNull);
    expect(snapshot?.events.single.attendeeCount, 9);
    expect(snapshot?.cachedAt, cachedAt.toUtc());
  });

  test(
    'lifecycle fields round-trip through an authenticated snapshot',
    () async {
      final cache = SharedPreferencesEventSnapshotCache();
      final cancelledAt = DateTime.utc(2026, 6, 30, 12);
      final event =
          _event(
            id: 'cancelled-owned-event',
            viewerRsvpStatus: RsvpStatus.going,
          ).copyWith(
            status: EventStatus.cancelled,
            isOwnedByViewer: true,
            cancelledAt: cancelledAt,
          );

      await cache.write(
        'user-a',
        EventSnapshot(events: [event], cachedAt: cancelledAt),
      );
      final cachedEvent = (await cache.read('user-a'))!.events.single;

      expect(cachedEvent.status, EventStatus.cancelled);
      expect(cachedEvent.isOwnedByViewer, isTrue);
      expect(cachedEvent.cancelledAt, cancelledAt);
    },
  );

  test('does not reuse a legacy participant-keyed snapshot', () async {
    SharedPreferences.setMockInitialValues({
      'participant_event_snapshot_v1:user-a': '{"legacy":true}',
    });
    final cache = SharedPreferencesEventSnapshotCache();

    expect(await cache.read('user-a'), isNull);
  });

  test('old snapshots default to active non-owner lifecycle state', () async {
    SharedPreferences.setMockInitialValues({
      'authenticated_event_snapshot_v1:user-a': jsonEncode({
        'cached_at': '2026-06-28T12:00:00Z',
        'events': [
          {
            'id': 'old-snapshot-event',
            'title': 'Saved Meet',
            'description': 'Saved before lifecycle fields existed.',
            'location_name': 'Test Garage',
            'host_name': 'Test Host',
            'start_time': '2026-07-01T18:00:00Z',
            'end_time': '2026-07-01T20:00:00Z',
            'attendee_count': 4,
            'rsvp_status': null,
          },
        ],
      }),
    });

    final snapshot = await SharedPreferencesEventSnapshotCache().read('user-a');
    final event = snapshot!.events.single;

    expect(event.status, EventStatus.active);
    expect(event.isOwnedByViewer, isFalse);
    expect(event.cancelledAt, isNull);
  });
}

Event _event({
  required String id,
  required RsvpStatus? viewerRsvpStatus,
  int attendeeCount = 4,
}) {
  return Event(
    id: id,
    title: 'Cached Meet',
    description: 'An event persisted in the snapshot cache.',
    locationName: 'Test Garage',
    hostName: 'Test Host',
    startTime: DateTime.utc(2026, 7, 1, 18),
    endTime: DateTime.utc(2026, 7, 1, 20),
    attendeeCount: attendeeCount,
    viewerRsvpStatus: viewerRsvpStatus,
  );
}
