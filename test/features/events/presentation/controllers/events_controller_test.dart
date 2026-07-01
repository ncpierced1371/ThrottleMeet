import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/core/errors/app_exception.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/event.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/event_snapshot.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/rsvp_status.dart';
import 'package:throttlemeet_v2/src/features/events/domain/repositories/events_repository.dart';
import 'package:throttlemeet_v2/src/features/events/presentation/controllers/events_controller.dart';

void main() {
  group('EventsController cached loading', () {
    final cachedAt = DateTime.utc(2026, 6, 30, 12);

    test('shows cached events before remote refresh completes', () async {
      final pendingLoad = Completer<List<Event>>();
      final repository = _FakeEventsRepository(
        cachedSnapshot: EventSnapshot(
          events: [_existingEvent],
          cachedAt: cachedAt,
        ),
      )..pendingLoad = pendingLoad;
      final controller = EventsController(repository: repository);
      addTearDown(controller.dispose);

      final load = controller.loadEvents();
      await Future<void>.delayed(Duration.zero);

      expect(controller.events, [_existingEvent]);
      expect(controller.isShowingCachedEvents, isTrue);
      expect(controller.cachedAt, cachedAt);
      expect(controller.isLoading, isTrue);

      pendingLoad.complete([_newEvent]);
      expect(await load, isTrue);
      expect(controller.events, [_newEvent]);
      expect(controller.isShowingCachedEvents, isFalse);
      expect(controller.cachedAt, isNull);
    });

    test(
      'remote failure keeps cached events and reports refresh error',
      () async {
        final repository = _FakeEventsRepository(
          cachedSnapshot: EventSnapshot(
            events: [_existingEvent],
            cachedAt: cachedAt,
          ),
        )..loadError = _failure;
        final controller = EventsController(repository: repository);
        addTearDown(controller.dispose);

        final succeeded = await controller.loadEvents();

        expect(succeeded, isFalse);
        expect(controller.events, [_existingEvent]);
        expect(controller.isShowingCachedEvents, isTrue);
        expect(controller.cachedAt, cachedAt);
        expect(controller.errorMessage, 'Unable to load events.');
      },
    );

    test('remote failure without cache leaves existing error state', () async {
      final repository = _FakeEventsRepository()..loadError = _failure;
      final controller = EventsController(repository: repository);
      addTearDown(controller.dispose);

      final succeeded = await controller.loadEvents();

      expect(succeeded, isFalse);
      expect(controller.events, isEmpty);
      expect(controller.isShowingCachedEvents, isFalse);
      expect(controller.cachedAt, isNull);
      expect(controller.errorMessage, 'Unable to load events.');
    });

    test(
      'tracks cached count and successful refresh/write timestamps',
      () async {
        final pendingLoad = Completer<List<Event>>();
        final repository = _FakeEventsRepository(
          cachedSnapshot: EventSnapshot(
            events: [_existingEvent],
            cachedAt: cachedAt,
          ),
        )..pendingLoad = pendingLoad;
        final now = DateTime.utc(2026, 6, 30, 13);
        final controller = EventsController(
          repository: repository,
          now: () => now,
        );
        addTearDown(controller.dispose);

        final load = controller.loadEvents();
        await Future<void>.delayed(Duration.zero);

        expect(controller.cachedEventCount, 1);
        expect(controller.latestCacheWriteAt, cachedAt);
        expect(controller.latestSuccessfulEventRefreshAt, isNull);

        pendingLoad.complete([_newEvent]);
        expect(await load, isTrue);

        expect(controller.cachedEventCount, 1);
        expect(controller.latestSuccessfulEventRefreshAt, now);
        expect(controller.latestCacheWriteAt, now);
      },
    );
  });

  group('EventsController refresh race protection', () {
    test('older success cannot overwrite a newer success', () async {
      final repository = _SequencedEventsRepository();
      final controller = EventsController(repository: repository);
      addTearDown(controller.dispose);

      final olderLoad = controller.loadEvents();
      await _waitForLoadRequests(repository, 1);
      final newerLoad = controller.loadEvents();
      await _waitForLoadRequests(repository, 2);

      repository.loadRequests[1].complete([_newEvent]);
      expect(await newerLoad, isTrue);
      repository.loadRequests[0].complete([_existingEvent]);
      expect(await olderLoad, isFalse);

      expect(controller.events, [_newEvent]);
      expect(controller.errorMessage, isNull);
      expect(controller.isLoading, isFalse);
      expect(controller.isShowingCachedEvents, isFalse);
      expect(repository.cacheWrites, [
        [_newEvent],
      ]);
    });

    test('older failure cannot overwrite a newer success', () async {
      final repository = _SequencedEventsRepository();
      final controller = EventsController(repository: repository);
      addTearDown(controller.dispose);

      final olderLoad = controller.loadEvents();
      await _waitForLoadRequests(repository, 1);
      final newerLoad = controller.loadEvents();
      await _waitForLoadRequests(repository, 2);

      repository.loadRequests[1].complete([_newEvent]);
      expect(await newerLoad, isTrue);
      repository.loadRequests[0].completeError(_failure);
      expect(await olderLoad, isFalse);

      expect(controller.events, [_newEvent]);
      expect(controller.errorMessage, isNull);
      expect(controller.errorType, isNull);
      expect(repository.cacheWrites, [
        [_newEvent],
      ]);
    });

    test('newer failure preserves accepted data and reports error', () async {
      final repository = _SequencedEventsRepository();
      final controller = EventsController(repository: repository);
      addTearDown(controller.dispose);

      final initialLoad = controller.loadEvents();
      await _waitForLoadRequests(repository, 1);
      repository.loadRequests[0].complete([_existingEvent]);
      expect(await initialLoad, isTrue);

      final olderLoad = controller.loadEvents();
      await _waitForLoadRequests(repository, 2);
      final newerLoad = controller.loadEvents();
      await _waitForLoadRequests(repository, 3);

      repository.loadRequests[1].complete([_newEvent]);
      expect(await olderLoad, isFalse);
      repository.loadRequests[2].completeError(_failure);
      expect(await newerLoad, isFalse);

      expect(controller.events, [_existingEvent]);
      expect(controller.errorMessage, 'Unable to load events.');
      expect(controller.isLoading, isFalse);
      expect(repository.cacheWrites, [
        [_existingEvent],
      ]);
    });
  });

  group('EventsController typed errors', () {
    final cases = [
      (
        AppErrorType.network,
        'No network connection. Check your connection and try again.',
      ),
      (AppErrorType.timeout, 'The request timed out. Please try again.'),
      (
        AppErrorType.authorization,
        'You do not have permission to perform this action.',
      ),
      (
        AppErrorType.validationOrServer,
        'The server could not complete the request. Please try again.',
      ),
      (AppErrorType.unknown, 'Unable to load events.'),
    ];

    for (final (type, message) in cases) {
      test('exposes a user message for $type', () async {
        final repository = _FakeEventsRepository()
          ..loadError = AppException(
            type: type,
            cause: Exception('Fake typed failure'),
          );
        final controller = EventsController(repository: repository);
        addTearDown(controller.dispose);

        final succeeded = await controller.loadEvents();

        expect(succeeded, isFalse);
        expect(controller.errorType, type);
        expect(controller.errorMessage, message);
        expect(controller.isLoading, isFalse);
      });
    }
  });

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

    test(
      'createNewEvent returns false and preserves events when refresh fails',
      () async {
        final repository = _FakeEventsRepository(events: [_existingEvent]);
        final controller = EventsController(repository: repository);
        addTearDown(controller.dispose);
        await controller.loadEvents();
        final successfulEvents = controller.events;
        repository.loadError = _failure;

        final succeeded = await controller.createNewEvent(_newEvent);

        expect(succeeded, isFalse);
        expect(controller.errorMessage, 'Unable to load events.');
        expect(controller.isLoading, isFalse);
        expect(controller.events, same(successfulEvents));
        expect(controller.events, [_existingEvent]);
        expect(repository.loadCallCount, 2);
      },
    );

    test('updateEvent write failure preserves successful state', () async {
      final repository = _FakeEventsRepository(events: [_existingEvent]);
      final controller = EventsController(repository: repository);
      addTearDown(controller.dispose);
      await controller.loadEvents();
      final successfulEvents = controller.events;
      repository.updateEventError = _failure;

      final succeeded = await controller.updateEvent(
        _existingEvent.copyWith(title: 'Updated Meet'),
      );

      expect(succeeded, isFalse);
      expect(controller.errorMessage, 'Unable to update event.');
      expect(controller.events, same(successfulEvents));
      expect(controller.events.single.title, 'Existing Meet');
      expect(repository.loadCallCount, 1);
    });

    test('cancelEvent write failure preserves successful state', () async {
      final repository = _FakeEventsRepository(events: [_existingEvent]);
      final controller = EventsController(repository: repository);
      addTearDown(controller.dispose);
      await controller.loadEvents();
      final successfulEvents = controller.events;
      repository.cancelError = _failure;

      final succeeded = await controller.cancelEvent(_existingEvent.id);

      expect(succeeded, isFalse);
      expect(controller.errorMessage, 'Unable to cancel event.');
      expect(controller.events, same(successfulEvents));
      expect(controller.events.single.status, EventStatus.active);
      expect(repository.loadCallCount, 1);
    });

    test(
      'successful edit with failed refresh preserves visible events',
      () async {
        final repository = _FakeEventsRepository(events: [_existingEvent]);
        final controller = EventsController(repository: repository);
        addTearDown(controller.dispose);
        await controller.loadEvents();
        final successfulEvents = controller.events;
        repository.loadError = _failure;

        final succeeded = await controller.updateEvent(
          _existingEvent.copyWith(title: 'Updated Meet'),
        );

        expect(succeeded, isFalse);
        expect(controller.errorMessage, 'Unable to load events.');
        expect(controller.events, same(successfulEvents));
        expect(controller.events.single.title, 'Existing Meet');
        expect(repository.loadCallCount, 2);
      },
    );

    test(
      'successful cancel with failed refresh preserves visible events',
      () async {
        final repository = _FakeEventsRepository(events: [_existingEvent]);
        final controller = EventsController(repository: repository);
        addTearDown(controller.dispose);
        await controller.loadEvents();
        final successfulEvents = controller.events;
        repository.loadError = _failure;

        final succeeded = await controller.cancelEvent(_existingEvent.id);

        expect(succeeded, isFalse);
        expect(controller.errorMessage, 'Unable to load events.');
        expect(controller.events, same(successfulEvents));
        expect(controller.events.single.status, EventStatus.active);
        expect(repository.loadCallCount, 2);
      },
    );

    test(
      'successful edit and refresh returns true with refreshed event',
      () async {
        final repository = _FakeEventsRepository(events: [_existingEvent]);
        final controller = EventsController(repository: repository);
        addTearDown(controller.dispose);
        await controller.loadEvents();
        final editedEvent = _existingEvent.copyWith(title: 'Updated Meet');

        final succeeded = await controller.updateEvent(editedEvent);

        expect(succeeded, isTrue);
        expect(controller.errorMessage, isNull);
        expect(controller.events.single.title, 'Updated Meet');
      },
    );

    test(
      'successful cancel and refresh returns true with cancelled event',
      () async {
        final repository = _FakeEventsRepository(events: [_existingEvent]);
        final controller = EventsController(repository: repository);
        addTearDown(controller.dispose);
        await controller.loadEvents();

        final succeeded = await controller.cancelEvent(_existingEvent.id);

        expect(succeeded, isTrue);
        expect(controller.errorMessage, isNull);
        expect(controller.events.single.status, EventStatus.cancelled);
        expect(controller.events.single.cancelledAt, isNotNull);
      },
    );

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

    test(
      'updateRsvp returns false and preserves events when refresh fails',
      () async {
        final repository = _FakeEventsRepository(events: [_existingEvent]);
        final controller = EventsController(repository: repository);
        addTearDown(controller.dispose);
        await controller.loadEvents();
        final successfulEvents = controller.events;
        repository.loadError = _failure;

        final succeeded = await controller.updateRsvp(
          eventId: _existingEvent.id,
          status: RsvpStatus.going,
        );

        expect(succeeded, isFalse);
        expect(controller.errorMessage, 'Unable to load events.');
        expect(controller.isLoading, isFalse);
        expect(controller.events, same(successfulEvents));
        expect(
          controller.events.single.viewerRsvpStatus,
          RsvpStatus.interested,
        );
        expect(repository.loadCallCount, 2);
      },
    );

    test(
      'successful create and refresh clear a prior mutation error',
      () async {
        final repository = _FakeEventsRepository(events: [_existingEvent])
          ..createError = _failure;
        final controller = EventsController(repository: repository);
        addTearDown(controller.dispose);
        await controller.loadEvents();
        await controller.createNewEvent(_newEvent);
        repository.createError = null;

        final succeeded = await controller.createNewEvent(_newEvent);

        expect(succeeded, isTrue);
        expect(controller.errorType, isNull);
        expect(controller.errorMessage, isNull);
        expect(controller.events, [_existingEvent, _newEvent]);
      },
    );

    test('successful RSVP and refresh clear a prior mutation error', () async {
      final repository = _FakeEventsRepository(events: [_existingEvent])
        ..updateError = _failure;
      final controller = EventsController(repository: repository);
      addTearDown(controller.dispose);
      await controller.loadEvents();
      await controller.updateRsvp(
        eventId: _existingEvent.id,
        status: RsvpStatus.going,
      );
      repository.updateError = null;

      final succeeded = await controller.updateRsvp(
        eventId: _existingEvent.id,
        status: RsvpStatus.going,
      );

      expect(succeeded, isTrue);
      expect(controller.errorType, isNull);
      expect(controller.errorMessage, isNull);
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
  _FakeEventsRepository({List<Event> events = const [], this.cachedSnapshot})
    : _events = List.of(events);

  final List<Event> _events;
  final List<List<Event>> cacheWrites = [];
  EventSnapshot? cachedSnapshot;
  Completer<List<Event>>? pendingLoad;
  Object? loadError;
  Object? createError;
  Object? updateError;
  Object? updateEventError;
  Object? cancelError;
  int loadCallCount = 0;

  @override
  Future<EventSnapshot?> getCachedEvents() async => cachedSnapshot;

  @override
  Future<void> cacheEvents(List<Event> events) async {
    cacheWrites.add(List.unmodifiable(events));
  }

  @override
  Future<List<Event>> getEvents() async {
    loadCallCount += 1;
    final error = loadError;
    if (error != null) {
      throw error;
    }
    final pending = pendingLoad;
    if (pending != null) {
      return pending.future;
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
  Future<void> updateEvent(Event event) async {
    final error = updateEventError;
    if (error != null) {
      throw error;
    }
    final index = _events.indexWhere((existing) => existing.id == event.id);
    if (index != -1) {
      _events[index] = event;
    }
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    final error = cancelError;
    if (error != null) {
      throw error;
    }
    final index = _events.indexWhere((event) => event.id == eventId);
    if (index != -1) {
      _events[index] = _events[index].copyWith(
        status: EventStatus.cancelled,
        cancelledAt: DateTime.utc(2026, 6, 30),
      );
    }
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

Future<void> _waitForLoadRequests(
  _SequencedEventsRepository repository,
  int count,
) async {
  while (repository.loadRequests.length < count) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _SequencedEventsRepository implements EventsRepository {
  final List<Completer<List<Event>>> loadRequests = [];
  final List<List<Event>> cacheWrites = [];

  @override
  Future<void> cacheEvents(List<Event> events) async {
    cacheWrites.add(List.unmodifiable(events));
  }

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<void> updateEvent(Event event) async {}

  @override
  Future<void> cancelEvent(String eventId) async {}

  @override
  Future<EventSnapshot?> getCachedEvents() async => null;

  @override
  Future<Event?> getEventById(String id) async => null;

  @override
  Future<List<Event>> getEvents() {
    final request = Completer<List<Event>>();
    loadRequests.add(request);
    return request.future;
  }

  @override
  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {}
}
