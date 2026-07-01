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
import 'package:throttlemeet_v2/src/features/events/domain/entities/event_rsvp_attendee.dart';
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
  test('builds an encoded Google Maps search URL', () {
    final uri = buildEventMapsUri('Cars & Coffee / San Diego');

    expect(
      uri.toString(),
      'https://www.google.com/maps/search/?api=1&query=Cars+%26+Coffee+%2F+San+Diego',
    );
    expect(uri.queryParameters['query'], 'Cars & Coffee / San Diego');
  });

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

  testWidgets('filters the loaded event list by All, Upcoming, and Mine', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 7, 1, 12);
    final repository = _ToggleEventsRepository(
      events: [
        _filterWidgetEvent(
          id: 'past-public',
          title: 'Past Public Meet',
          startTime: now.subtract(const Duration(days: 1)),
        ),
        _filterWidgetEvent(
          id: 'future-public',
          title: 'Future Public Meet',
          startTime: now.add(const Duration(days: 1)),
        ),
        _filterWidgetEvent(
          id: 'owned-past',
          title: 'Owned Past Meet',
          startTime: now.subtract(const Duration(days: 2)),
          isOwnedByViewer: true,
        ),
        _filterWidgetEvent(
          id: 'interested-future',
          title: 'Interested Future Meet',
          startTime: now.add(const Duration(days: 2)),
          viewerRsvpStatus: RsvpStatus.interested,
        ),
      ],
    );
    final controller = EventsController(repository: repository, now: () => now);
    addTearDown(controller.dispose);
    await controller.loadEvents();

    await tester.pumpWidget(_eventsListApp(controller));

    expect(find.text('Past Public Meet'), findsOneWidget);
    expect(find.text('Future Public Meet'), findsOneWidget);
    expect(find.text('Owned Past Meet'), findsOneWidget);
    expect(find.text('Interested Future Meet'), findsOneWidget);

    await tester.tap(find.text('Upcoming'));
    await tester.pump();

    expect(find.text('Past Public Meet'), findsNothing);
    expect(find.text('Owned Past Meet'), findsNothing);
    expect(find.text('Future Public Meet'), findsOneWidget);
    expect(find.text('Interested Future Meet'), findsOneWidget);

    await tester.tap(find.text('Mine'));
    await tester.pump();

    expect(find.text('Past Public Meet'), findsNothing);
    expect(find.text('Future Public Meet'), findsNothing);
    expect(find.text('Owned Past Meet'), findsOneWidget);
    expect(find.text('Interested Future Meet'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pump();

    expect(find.text('Past Public Meet'), findsOneWidget);
    expect(find.text('Future Public Meet'), findsOneWidget);
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
    expect(find.text('Open in Maps'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Organizer Attendance'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Organizer Attendance'), findsOneWidget);

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
    expect(find.text('Organizer Attendance'), findsNothing);
    expect(nonOwnerRepository.ownerRsvpCallCount, 0);
  });

  testWidgets('owner attendance groups statuses and hides user IDs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository =
        _ToggleEventsRepository(
            events: [_lifecycleEvent(isOwnedByViewer: true)],
          )
          ..ownerRsvpAttendees = [
            EventRsvpAttendee(
              userId: 'private-user-a',
              displayName: 'Avery Driver',
              avatarUrl: 'https://example.com/avery.jpg',
              status: RsvpStatus.going,
              updatedAt: DateTime.utc(2026, 7, 1, 12),
            ),
            EventRsvpAttendee(
              userId: 'private-user-b',
              displayName: null,
              avatarUrl: null,
              status: RsvpStatus.interested,
              updatedAt: DateTime.utc(2026, 7, 1, 13),
            ),
            EventRsvpAttendee(
              userId: 'private-user-c',
              displayName: 'Casey',
              avatarUrl: null,
              status: RsvpStatus.notGoing,
              updatedAt: DateTime.utc(2026, 7, 1, 14),
            ),
          ];
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
    await tester.pumpAndSettle();

    expect(find.text('Organizer Attendance'), findsOneWidget);
    expect(find.text('Going: 1'), findsOneWidget);
    expect(find.text('Interested: 1'), findsOneWidget);
    expect(find.text('Not going: 1'), findsOneWidget);
    expect(find.text('Avery Driver'), findsOneWidget);
    expect(find.text('Anonymous tester'), findsOneWidget);
    expect(find.text('Casey'), findsOneWidget);
    expect(find.textContaining('private-user-'), findsNothing);
  });

  testWidgets('owner attendance failure shows retry without breaking detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ToggleEventsRepository(
      events: [_lifecycleEvent(isOwnedByViewer: true)],
    )..ownerRsvpError = StateError('attendance unavailable');
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
    await tester.pumpAndSettle();

    expect(find.text('Lifecycle Meet'), findsOneWidget);
    expect(find.text('Organizer Attendance'), findsOneWidget);
    expect(find.text('Unable to load organizer attendance.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repository.ownerRsvpError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.ownerRsvpCallCount, 2);
    expect(find.text('No authenticated RSVPs yet.'), findsOneWidget);
    expect(find.text('Lifecycle Meet'), findsOneWidget);
  });

  testWidgets('hides maps action when the event location is empty', (
    tester,
  ) async {
    final repository = _ToggleEventsRepository(
      events: [_lifecycleEvent(locationName: '')],
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

    expect(find.text('Open in Maps'), findsNothing);
  });

  testWidgets('shows an error when the maps app cannot launch', (tester) async {
    final repository = _ToggleEventsRepository(events: [_lifecycleEvent()]);
    final controller = EventsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadEvents();
    Uri? launchedUri;

    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          controller: controller,
          eventId: 'lifecycle-event',
          locationLauncher: (uri) async {
            launchedUri = uri;
            return false;
          },
        ),
      ),
    );

    await tester.tap(find.text('Open in Maps'));
    await tester.pump();

    expect(launchedUri, buildEventMapsUri('Test Garage'));
    expect(find.text('Unable to open maps for this location.'), findsOneWidget);
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
  String locationName = 'Test Garage',
}) {
  return Event(
    id: 'lifecycle-event',
    title: 'Lifecycle Meet',
    description: 'An event with owner lifecycle controls.',
    locationName: locationName,
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

Event _filterWidgetEvent({
  required String id,
  required String title,
  required DateTime startTime,
  bool isOwnedByViewer = false,
  RsvpStatus? viewerRsvpStatus,
}) {
  return Event(
    id: id,
    title: title,
    description: 'Filter fixture',
    locationName: 'Test Garage',
    hostName: 'Test Host',
    startTime: startTime,
    endTime: startTime.add(const Duration(hours: 2)),
    attendeeCount: 0,
    viewerRsvpStatus: viewerRsvpStatus,
    isOwnedByViewer: isOwnedByViewer,
  );
}

class _ToggleEventsRepository implements EventsRepository {
  _ToggleEventsRepository({List<Event>? events, this.cachedSnapshot})
    : _events = List.of(events ?? SeedEvents.build());

  bool shouldFail = false;
  final List<Event> _events;
  final EventSnapshot? cachedSnapshot;
  int cancelCallCount = 0;
  List<EventRsvpAttendee> ownerRsvpAttendees = const [];
  Object? ownerRsvpError;
  int ownerRsvpCallCount = 0;

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
  Future<List<EventRsvpAttendee>> getEventRsvpsForOwner(String eventId) async {
    ownerRsvpCallCount += 1;
    final error = ownerRsvpError;
    if (error != null) {
      throw error;
    }
    return ownerRsvpAttendees;
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
  Future<List<EventRsvpAttendee>> getEventRsvpsForOwner(String eventId) async {
    return const [];
  }

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

  @override
  Future<UserProfile> update({
    required String userId,
    required String displayName,
    String? avatarUrl,
  }) async {
    return UserProfile(
      id: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      createdAt: DateTime.utc(2026, 6, 30),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
  }
}
