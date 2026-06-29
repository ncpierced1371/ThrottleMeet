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

  test('snapshots are participant-specific', () async {
    final cache = SharedPreferencesEventSnapshotCache();
    final participantACachedAt = DateTime.utc(2026, 6, 28, 12);
    final participantBCachedAt = DateTime.utc(2026, 6, 28, 13);

    await cache.write(
      'participant-a',
      EventSnapshot(
        events: [_event(id: 'event-a', viewerRsvpStatus: RsvpStatus.going)],
        cachedAt: participantACachedAt,
      ),
    );
    await cache.write(
      'participant-b',
      EventSnapshot(
        events: [
          _event(id: 'event-b', viewerRsvpStatus: RsvpStatus.interested),
        ],
        cachedAt: participantBCachedAt,
      ),
    );

    final participantA = await cache.read('participant-a');
    final participantB = await cache.read('participant-b');
    final participantC = await cache.read('participant-c');

    expect(participantA?.events.single.id, 'event-a');
    expect(participantA?.events.single.viewerRsvpStatus, RsvpStatus.going);
    expect(participantA?.cachedAt, participantACachedAt);
    expect(participantB?.events.single.id, 'event-b');
    expect(participantB?.events.single.viewerRsvpStatus, RsvpStatus.interested);
    expect(participantB?.cachedAt, participantBCachedAt);
    expect(participantC, isNull);
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
      'participant-a',
      EventSnapshot(events: [event], cachedAt: cachedAt),
    );
    final snapshot = await cache.read('participant-a');

    expect(snapshot?.events.single.viewerRsvpStatus, isNull);
    expect(snapshot?.events.single.attendeeCount, 9);
    expect(snapshot?.cachedAt, cachedAt.toUtc());
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
