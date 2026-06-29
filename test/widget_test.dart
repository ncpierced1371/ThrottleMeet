import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/features/events/data/repositories/in_memory_events_repository.dart';
import 'package:throttlemeet_v2/src/features/events/data/seeds/seed_events.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/event.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/event_snapshot.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/rsvp_status.dart';
import 'package:throttlemeet_v2/src/features/events/domain/repositories/events_repository.dart';
import 'package:throttlemeet_v2/src/features/events/presentation/controllers/events_controller.dart';
import 'package:throttlemeet_v2/src/features/events/presentation/screens/event_detail_screen.dart';
import 'package:throttlemeet_v2/src/features/events/presentation/screens/events_list_screen.dart';
import 'package:throttlemeet_v2/src/features/events/presentation/widgets/event_card.dart';

void main() {
  testWidgets('shows events without a live backend', (tester) async {
    final controller = EventsController(repository: InMemoryEventsRepository());
    addTearDown(controller.dispose);
    await controller.loadEvents();

    await tester.pumpWidget(
      MaterialApp(home: EventsListScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ThrottleMeet'), findsOneWidget);
    expect(find.text('Spring Canyon Run'), findsOneWidget);
    expect(find.text('Create Event'), findsOneWidget);
  });

  testWidgets('shows an event without a viewer RSVP', (tester) async {
    final event = Event(
      id: 'event-without-rsvp',
      title: 'Unanswered Meet',
      description: 'No RSVP has been submitted.',
      locationName: 'Test Garage',
      hostName: 'Test Host',
      startTime: DateTime(2026, 7, 1, 18),
      endTime: DateTime(2026, 7, 1, 20),
      attendeeCount: 4,
      viewerRsvpStatus: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventCard(event: event, onTap: () {}),
        ),
      ),
    );

    expect(find.text('Unanswered Meet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retry state instead of empty state on load failure', (
    tester,
  ) async {
    final repository = _ToggleEventsRepository()..shouldFail = true;
    final controller = EventsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadEvents();

    await tester.pumpWidget(
      MaterialApp(home: EventsListScreen(controller: controller)),
    );

    expect(find.text('Unable to load events'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No events yet'), findsNothing);

    repository.shouldFail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Spring Canyon Run'), findsOneWidget);
    expect(find.text('Unable to load events'), findsNothing);
  });

  testWidgets('shows the empty state after a successful empty load', (
    tester,
  ) async {
    final controller = EventsController(
      repository: _ToggleEventsRepository(events: const []),
    );
    addTearDown(controller.dispose);
    await controller.loadEvents();

    await tester.pumpWidget(
      MaterialApp(home: EventsListScreen(controller: controller)),
    );

    expect(find.text('No events yet'), findsOneWidget);
    expect(find.text('Unable to load events'), findsNothing);
  });

  testWidgets('preserves loaded events when refresh fails', (tester) async {
    final repository = _ToggleEventsRepository();
    final controller = EventsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadEvents();

    repository.shouldFail = true;
    await controller.loadEvents();

    await tester.pumpWidget(
      MaterialApp(home: EventsListScreen(controller: controller)),
    );

    expect(find.text('Spring Canyon Run'), findsOneWidget);
    expect(find.text('Unable to load events.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No events yet'), findsNothing);
  });

  testWidgets('labels cached events when remote refresh fails', (tester) async {
    final cachedEvents = SeedEvents.build();
    final repository = _ToggleEventsRepository(
      cachedSnapshot: EventSnapshot(
        events: cachedEvents,
        cachedAt: DateTime.utc(2026, 6, 28, 12),
      ),
    )..shouldFail = true;
    final controller = EventsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadEvents();

    await tester.pumpWidget(
      MaterialApp(home: EventsListScreen(controller: controller)),
    );

    expect(find.text('Spring Canyon Run'), findsOneWidget);
    expect(find.text('Showing saved events'), findsOneWidget);
    expect(find.text('Unable to load events.'), findsOneWidget);
  });

  testWidgets('disables RSVP choices while an update is pending', (
    tester,
  ) async {
    final repository = _PendingRsvpRepository();
    final controller = EventsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadEvents();

    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          controller: controller,
          eventId: repository.event.id,
        ),
      ),
    );

    await tester.tap(find.text('Going'));
    await tester.pump();

    expect(repository.updateCallCount, 1);
    expect(
      tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)),
      everyElement(
        isA<ChoiceChip>().having(
          (chip) => chip.onSelected,
          'onSelected',
          isNull,
        ),
      ),
    );

    await tester.tap(find.text('Interested'));
    await tester.pump();
    expect(repository.updateCallCount, 1);

    repository.completeUpdate();
    await tester.pumpAndSettle();

    expect(find.text('RSVP updated to Going.'), findsOneWidget);
  });
}

class _ToggleEventsRepository implements EventsRepository {
  _ToggleEventsRepository({List<Event>? events, this.cachedSnapshot})
    : _events = List.of(events ?? SeedEvents.build());

  bool shouldFail = false;
  final List<Event> _events;
  final EventSnapshot? cachedSnapshot;

  @override
  Future<EventSnapshot?> getCachedEvents() async => cachedSnapshot;

  @override
  Future<void> createEvent(Event event) async {
    _events.add(event);
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
  Future<List<Event>> getEvents() async {
    if (shouldFail) {
      throw StateError('Backend unavailable');
    }
    return List.unmodifiable(_events);
  }

  @override
  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {}
}

class _PendingRsvpRepository implements EventsRepository {
  final Event event = Event(
    id: 'pending-rsvp-event',
    title: 'Pending RSVP Meet',
    description: 'An event used to test pending RSVP state.',
    locationName: 'Test Garage',
    hostName: 'Test Host',
    startTime: DateTime(2026, 7, 1, 18),
    endTime: DateTime(2026, 7, 1, 20),
    attendeeCount: 0,
    viewerRsvpStatus: null,
  );

  final Completer<void> _updateCompleter = Completer<void>();
  int updateCallCount = 0;

  @override
  Future<EventSnapshot?> getCachedEvents() async => null;

  void completeUpdate() {
    _updateCompleter.complete();
  }

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<Event?> getEventById(String id) async => id == event.id ? event : null;

  @override
  Future<List<Event>> getEvents() async => [event];

  @override
  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) {
    updateCallCount += 1;
    return _updateCompleter.future;
  }
}
