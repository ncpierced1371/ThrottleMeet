import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/event.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/rsvp_status.dart';
import 'package:throttlemeet_v2/src/features/events/domain/repositories/events_repository.dart';
import 'package:throttlemeet_v2/src/features/events/presentation/controllers/events_controller.dart';

void main() {
  group('EventsController failure paths', () {
    test('loadEvents sets an error and resets loading after failure', () async {
      final repository = _FakeEventsRepository()..loadError = _failure;
      final controller = EventsController(repository: repository);
      addTearDown(controller.dispose);

      await controller.loadEvents();

      expect(controller.errorMessage, 'Unable to load events.');
      expect(controller.isLoading, isFalse);
      expect(controller.events, isEmpty);
    });

    test(
      'refresh failure preserves the last successfully loaded events',
      () async {
        final repository = _FakeEventsRepository(events: [_existingEvent]);
        final controller = EventsController(repository: repository);
        addTearDown(controller.dispose);
        await controller.loadEvents();
        final successfulEvents = controller.events;

        repository.loadError = _failure;
        await controller.loadEvents();

        expect(controller.errorMessage, 'Unable to load events.');
        expect(controller.isLoading, isFalse);
        expect(controller.events, same(successfulEvents));
        expect(controller.events, [_existingEvent]);
      },
    );

    test('createNewEvent failure preserves successful state', () async {
      final repository = _FakeEventsRepository(events: [_existingEvent]);
      final controller = EventsController(repository: repository);
      addTearDown(controller.dispose);
      await controller.loadEvents();
      final successfulEvents = controller.events;
      repository.createError = _failure;

      final succeeded = await controller.createNewEvent(_newEvent);

      expect(succeeded, isFalse);
      expect(controller.errorMessage, 'Unable to create event.');
      expect(controller.isLoading, isFalse);
      expect(controller.events, same(successfulEvents));
      expect(controller.events, [_existingEvent]);
      expect(repository.loadCallCount, 1);
    });

    test('updateRsvp failure preserves successful state', () async {
      final repository = _FakeEventsRepository(events: [_existingEvent]);
      final controller = EventsController(repository: repository);
      addTearDown(controller.dispose);
      await controller.loadEvents();
      final successfulEvents = controller.events;
      repository.updateError = _failure;

      final succeeded = await controller.updateRsvp(
        eventId: _existingEvent.id,
        status: RsvpStatus.going,
      );

      expect(succeeded, isFalse);
      expect(controller.errorMessage, 'Unable to update RSVP.');
      expect(controller.isLoading, isFalse);
      expect(controller.events, same(successfulEvents));
      expect(controller.events.single.viewerRsvpStatus, RsvpStatus.interested);
      expect(repository.loadCallCount, 1);
    });
  });
}

final _failure = StateError('Fake repository failure');

final _existingEvent = Event(
  id: 'existing-event',
  title: 'Existing Meet',
  description: 'An event loaded before the failure.',
  locationName: 'Test Garage',
  hostName: 'Test Host',
  startTime: DateTime.utc(2026, 7, 1, 18),
  endTime: DateTime.utc(2026, 7, 1, 20),
  attendeeCount: 4,
  viewerRsvpStatus: RsvpStatus.interested,
);

final _newEvent = Event(
  id: 'new-event',
  title: 'New Meet',
  description: 'An event that fails to save.',
  locationName: 'Test Garage',
  hostName: 'Test Host',
  startTime: DateTime.utc(2026, 7, 2, 18),
  endTime: DateTime.utc(2026, 7, 2, 20),
  attendeeCount: 0,
  viewerRsvpStatus: null,
);

class _FakeEventsRepository implements EventsRepository {
  _FakeEventsRepository({List<Event> events = const []})
    : _events = List.of(events);

  final List<Event> _events;
  Object? loadError;
  Object? createError;
  Object? updateError;
  int loadCallCount = 0;

  @override
  Future<List<Event>> getEvents() async {
    loadCallCount += 1;
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return List.unmodifiable(_events);
  }

  @override
  Future<Event?> getEventById(String id) async {
    for (final event in _events) {
      if (event.id == id) {
        return event;
      }
    }
    return null;
  }

  @override
  Future<void> createEvent(Event event) async {
    final error = createError;
    if (error != null) {
      throw error;
    }
    _events.add(event);
  }

  @override
  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {
    final error = updateError;
    if (error != null) {
      throw error;
    }
  }
}
