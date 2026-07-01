import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/entities/user_profile.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/repositories/auth_gateway.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/repositories/profile_repository.dart';
import 'package:throttlemeet_v2/src/features/auth/presentation/controllers/auth_bootstrap_controller.dart';
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

Widget _eventsListApp(EventsController controller) {
  final authController = AuthBootstrapController(
    authGateway: _WidgetAuthGateway(),
    profileRepository: _WidgetProfileRepository(),
  );
  addTearDown(authController.dispose);
  return MaterialApp(
    home: EventsListScreen(
      controller: controller,
      authController: authController,
    ),
  );
}

void main() {
  testWidgets('shows events without a live backend', (tester) async {
    final controller = EventsController(repository: InMemoryEventsRepository());
    addTearDown(controller.dispose);
    await controller.loadEvents();

    await tester.pumpWidget(_eventsListApp(controller));
    await tester.pumpAndSettle();

    expect(find.text('Throttle Meet'), findsOneWidget);
    expect(find.text('Discover local automotive events'), findsOneWidget);
    expect(find.text('Spring Canyon Run'), findsOneWidget);
    expect(find.text('Create Event'), findsOneWidget);
  });

  testWidgets('shows an event without a viewer RSVP', (tester) async {
    var wasTapped = false;
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
          body: EventCard(event: event, onTap: () => wasTapped = true),
        ),
      ),
    );

    expect(find.text('Unanswered Meet'), findsOneWidget);
    expect(find.text('Test Garage'), findsOneWidget);
    expect(find.text('Test Host'), findsOneWidget);
    expect(find.text('4 attendees'), findsOneWidget);

    await tester.tap(find.byType(EventCard));

    expect(wasTapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retry state instead of empty state on load failure', (
    tester,
  ) async {
    final repository = _ToggleEventsRepository()..shouldFail = true;
    final controller = EventsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadEvents();

    await tester.pumpWidget(_eventsListApp(controller));

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

    await tester.pumpWidget(_eventsListApp(controller));

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

    await tester.pumpWidget(_eventsListApp(controller));

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

    await tester.pumpWidget(_eventsListApp(controller));

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

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Going'));
    await tester.pump();

    expect(repository.updateCallCount, 1);
    final pendingSelector = tester.widget<SegmentedButton<RsvpStatus>>(
      find.byType(SegmentedButton<RsvpStatus>),
    );
    expect(pendingSelector.onSelectionChanged, isNull);

    await tester.tap(find.text('Interested'));
    await tester.pump();
    expect(repository.updateCallCount, 1);

    repository.completeUpdate();
    await tester.pumpAndSettle();

    expect(find.text('RSVP updated to Going.'), findsOneWidget);
  });

  testWidgets('shows owner controls only for an owned active event', (
    tester,
  ) async {
    final ownedRepository = _ToggleEventsRepository(
      events: [_lifecycleEvent(isOwnedByViewer: true)],
    );
    final ownedController = EventsController(repository: ownedRepository);
    addTearDown(ownedController.dispose);
    await ownedController.loadEvents();

    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          controller: ownedController,
          eventId: 'lifecycle-event',
        ),
      ),
    );

    final attendanceLabel = tester.widget<Text>(find.text('Attendance'));
    final interestedLabel = tester.widget<Text>(find.text('Interested'));
    expect(attendanceLabel.maxLines, 1);
    expect(attendanceLabel.softWrap, isFalse);
    expect(interestedLabel.maxLines, 1);
    expect(interestedLabel.softWrap, isFalse);

    final metadataCard = find.ancestor(
      of: find.text('Attendance'),
      matching: find.byType(Card),
    );
    final aboutCard = find.ancestor(
      of: find.text('About this event'),
      matching: find.byType(Card),
    );
    final rsvpCard = find.ancestor(
      of: find.text('RSVP'),
      matching: find.byType(Card),
    );
    expect(tester.getSize(aboutCard).width, tester.getSize(metadataCard).width);
    expect(tester.getSize(rsvpCard).width, tester.getSize(metadataCard).width);

    expect(find.byTooltip('Edit event'), findsOneWidget);
    expect(find.byTooltip('Cancel event'), findsOneWidget);

    final nonOwnerRepository = _ToggleEventsRepository(
      events: [_lifecycleEvent()],
    );
    final nonOwnerController = EventsController(repository: nonOwnerRepository);
    addTearDown(nonOwnerController.dispose);
    await nonOwnerController.loadEvents();

    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          controller: nonOwnerController,
          eventId: 'lifecycle-event',
        ),
      ),
    );

    expect(find.byTooltip('Edit event'), findsNothing);
    expect(find.byTooltip('Cancel event'), findsNothing);
  });

  testWidgets('cancelled events show a banner and disable RSVP', (
    tester,
  ) async {
    final repository = _ToggleEventsRepository(
      events: [
        _lifecycleEvent(isOwnedByViewer: true, status: EventStatus.cancelled),
      ],
    );
    final controller = EventsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadEvents();

    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          controller: controller,
          eventId: 'lifecycle-event',
        ),
      ),
    );

    expect(find.text('Cancelled event'), findsOneWidget);
    expect(find.byTooltip('Edit event'), findsNothing);
    expect(find.byTooltip('Cancel event'), findsNothing);
    final cancelledSelector = tester.widget<SegmentedButton<RsvpStatus>>(
      find.byType(SegmentedButton<RsvpStatus>),
    );
    expect(cancelledSelector.onSelectionChanged, isNull);
    expect(cancelledSelector.selected, {RsvpStatus.going});
  });

  testWidgets('cancel requires confirmation before invoking controller', (
    tester,
  ) async {
    final repository = _ToggleEventsRepository(
      events: [_lifecycleEvent(isOwnedByViewer: true)],
    );
    final controller = EventsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadEvents();

    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          controller: controller,
          eventId: 'lifecycle-event',
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancel event'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this event?'), findsOneWidget);

    await tester.tap(find.text('Keep Event'));
    await tester.pumpAndSettle();
    expect(repository.cancelCallCount, 0);

    await tester.tap(find.byTooltip('Cancel event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Event'));
    await tester.pumpAndSettle();

    expect(repository.cancelCallCount, 1);
    expect(find.text('Cancelled event'), findsOneWidget);
  });
}

Event _lifecycleEvent({
  bool isOwnedByViewer = false,
  EventStatus status = EventStatus.active,
}) {
  return Event(
    id: 'lifecycle-event',
    title: 'Lifecycle Meet',
    description: 'An event with owner lifecycle controls.',
    locationName: 'Test Garage',
    hostName: 'Test Host',
    startTime: DateTime(2026, 7, 1, 18),
    endTime: DateTime(2026, 7, 1, 20),
    attendeeCount: 2,
    viewerRsvpStatus: RsvpStatus.going,
    status: status,
    isOwnedByViewer: isOwnedByViewer,
    cancelledAt: status == EventStatus.cancelled
        ? DateTime.utc(2026, 6, 30)
        : null,
  );
}

class _ToggleEventsRepository implements EventsRepository {
  _ToggleEventsRepository({List<Event>? events, this.cachedSnapshot})
    : _events = List.of(events ?? SeedEvents.build());

  bool shouldFail = false;
  final List<Event> _events;
  final EventSnapshot? cachedSnapshot;
  int cancelCallCount = 0;

  @override
  Future<EventSnapshot?> getCachedEvents() async => cachedSnapshot;

  @override
  Future<void> cacheEvents(List<Event> events) async {}

  @override
  Future<void> createEvent(Event event) async {
    _events.add(event);
  }

  @override
  Future<void> updateEvent(Event event) async {
    final index = _events.indexWhere((existing) => existing.id == event.id);
    if (index != -1) {
      _events[index] = event;
    }
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    cancelCallCount += 1;
    final index = _events.indexWhere((event) => event.id == eventId);
    if (index != -1) {
      _events[index] = _events[index].copyWith(
        status: EventStatus.cancelled,
        cancelledAt: DateTime.utc(2026, 6, 30),
      );
    }
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

  @override
  Future<void> cacheEvents(List<Event> events) async {}

  void completeUpdate() {
    _updateCompleter.complete();
  }

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<void> updateEvent(Event event) async {}

  @override
  Future<void> cancelEvent(String eventId) async {}

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

class _WidgetAuthGateway implements AuthGateway {
  @override
  String? get currentUserId => 'widget-user';

  @override
  Future<String> signInAnonymously() async => 'widget-user';
}

class _WidgetProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> load(String userId) async {
    return UserProfile(
      id: userId,
      displayName: null,
      createdAt: DateTime.utc(2026, 6, 30),
      updatedAt: DateTime.utc(2026, 6, 30),
    );
  }

  @override
  Future<void> upsert(String userId) async {}
}
