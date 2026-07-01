import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/app.dart';
import 'package:throttlemeet_v2/src/core/build_info.dart';
import 'package:throttlemeet_v2/src/core/platform/platform_info.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/entities/user_profile.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/repositories/auth_gateway.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/repositories/profile_repository.dart';
import 'package:throttlemeet_v2/src/features/auth/presentation/controllers/auth_bootstrap_controller.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/event.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/event_snapshot.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/rsvp_status.dart';
import 'package:throttlemeet_v2/src/features/events/domain/repositories/events_repository.dart';
import 'package:throttlemeet_v2/src/features/events/presentation/controllers/events_controller.dart';

void main() {
  testWidgets('events list opens discoverable Diagnostics/About screen', (
    tester,
  ) async {
    final authController = AuthBootstrapController(
      authGateway: _FakeAuthGateway(currentUserId: 'diagnostic-user'),
      profileRepository: _FakeProfileRepository(),
    );
    addTearDown(authController.dispose);

    await tester.pumpWidget(
      ThrottleMeetApp(
        authBootstrapController: authController,
        eventsControllerFactory: () =>
            EventsController(repository: _TrackingEventsRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Diagnostics'), findsOneWidget);
    expect(find.byTooltip('Refresh events'), findsOneWidget);
    expect(find.text('Create Event'), findsWidgets);

    await tester.tap(find.byTooltip('Diagnostics'));
    await tester.pumpAndSettle();

    expect(find.text('Settings & About'), findsOneWidget);
    expect(
      find.textContaining('Version ${BuildInfo.versionWithBuild}'),
      findsOneWidget,
    );
    expect(find.text(PlatformInfo.current), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Copy diagnostic report'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Copy diagnostic report'), findsOneWidget);
  });

  testWidgets('does not construct or load events before auth is ready', (
    tester,
  ) async {
    final authGateway = _FakeAuthGateway()..pendingSignIn = Completer<String>();
    final authController = AuthBootstrapController(
      authGateway: authGateway,
      profileRepository: _FakeProfileRepository(),
    );
    addTearDown(authController.dispose);
    final eventsRepository = _TrackingEventsRepository();
    var eventsControllerCreationCount = 0;

    await tester.pumpWidget(
      ThrottleMeetApp(
        authBootstrapController: authController,
        eventsControllerFactory: () {
          eventsControllerCreationCount += 1;
          return EventsController(repository: eventsRepository);
        },
      ),
    );
    await tester.pump();

    expect(authController.state, AuthBootstrapState.initializing);
    expect(eventsControllerCreationCount, 0);
    expect(eventsRepository.loadCount, 0);

    authGateway.pendingSignIn!.complete('authenticated-user');
    await tester.pumpAndSettle();

    expect(authController.state, AuthBootstrapState.ready);
    expect(eventsControllerCreationCount, 1);
    expect(eventsRepository.loadCount, 1);
  });

  testWidgets('profile failure still loads and displays cached events', (
    tester,
  ) async {
    final profileError = StateError('profile offline');
    final profileRepository = _FakeProfileRepository()
      ..upsertError = profileError;
    final authController = AuthBootstrapController(
      authGateway: _FakeAuthGateway(currentUserId: 'user-a'),
      profileRepository: profileRepository,
    );
    addTearDown(authController.dispose);
    final eventsRepository = _TrackingEventsRepository(
      cachedSnapshot: EventSnapshot(
        events: [_cachedEvent],
        cachedAt: DateTime.utc(2026, 6, 29, 12),
      ),
      remoteError: StateError('events offline'),
    );
    var eventsControllerCreationCount = 0;

    await tester.pumpWidget(
      ThrottleMeetApp(
        authBootstrapController: authController,
        eventsControllerFactory: () {
          eventsControllerCreationCount += 1;
          return EventsController(repository: eventsRepository);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(authController.state, AuthBootstrapState.ready);
    expect(authController.profileSyncStatus, ProfileSyncStatus.error);
    expect(authController.profileError, same(profileError));
    expect(eventsControllerCreationCount, 1);
    expect(eventsRepository.loadCount, 1);
    expect(find.text('Offline Snapshot Meet'), findsOneWidget);
    expect(find.text('Showing saved events'), findsOneWidget);
    expect(find.text('Unable to load events.'), findsOneWidget);
    expect(
      find.text('Profile unavailable. Saved events are still available.'),
      findsOneWidget,
    );
  });

  testWidgets('profile retry clears warning without recreating events', (
    tester,
  ) async {
    final profileRepository = _FakeProfileRepository()
      ..upsertError = StateError('profile offline');
    final authGateway = _FakeAuthGateway(currentUserId: 'user-a');
    final authController = AuthBootstrapController(
      authGateway: authGateway,
      profileRepository: profileRepository,
    );
    addTearDown(authController.dispose);
    final eventsRepository = _TrackingEventsRepository();
    var eventsControllerCreationCount = 0;

    await tester.pumpWidget(
      ThrottleMeetApp(
        authBootstrapController: authController,
        eventsControllerFactory: () {
          eventsControllerCreationCount += 1;
          return EventsController(repository: eventsRepository);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(authController.profileSyncStatus, ProfileSyncStatus.error);
    expect(find.text('Retry profile'), findsOneWidget);
    profileRepository.upsertError = null;

    await tester.tap(find.text('Retry profile'));
    await tester.pumpAndSettle();

    expect(authController.profileSyncStatus, ProfileSyncStatus.ready);
    expect(authController.profileError, isNull);
    expect(eventsControllerCreationCount, 1);
    expect(eventsRepository.loadCount, 1);
    expect(authGateway.anonymousSignInCount, 0);
    expect(
      find.text('Profile unavailable. Saved events are still available.'),
      findsNothing,
    );
  });

  testWidgets('auth failure remains blocking', (tester) async {
    final authController = AuthBootstrapController(
      authGateway: _FakeAuthGateway(signInError: StateError('auth failed')),
      profileRepository: _FakeProfileRepository(),
    );
    addTearDown(authController.dispose);
    var eventsControllerCreationCount = 0;

    await tester.pumpWidget(
      ThrottleMeetApp(
        authBootstrapController: authController,
        eventsControllerFactory: () {
          eventsControllerCreationCount += 1;
          return EventsController(repository: _TrackingEventsRepository());
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(authController.state, AuthBootstrapState.error);
    expect(eventsControllerCreationCount, 0);
    expect(find.text('Unable to start Throttle Meet.'), findsOneWidget);
  });

  testWidgets('authenticated user change recreates EventsController', (
    tester,
  ) async {
    final authGateway = _FakeAuthGateway(currentUserId: 'user-a');
    final authController = AuthBootstrapController(
      authGateway: authGateway,
      profileRepository: _FakeProfileRepository(),
    );
    addTearDown(authController.dispose);
    final eventsRepository = _TrackingEventsRepository();
    var eventsControllerCreationCount = 0;

    await tester.pumpWidget(
      ThrottleMeetApp(
        authBootstrapController: authController,
        eventsControllerFactory: () {
          eventsControllerCreationCount += 1;
          return EventsController(repository: eventsRepository);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(eventsControllerCreationCount, 1);

    authGateway.currentUserId = 'user-b';
    await authController.bootstrap();
    await tester.pumpAndSettle();

    expect(authController.userId, 'user-b');
    expect(eventsControllerCreationCount, 2);
    expect(eventsRepository.loadCount, 2);
  });
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({this.currentUserId, this.signInError});

  @override
  String? currentUserId;
  final Object? signInError;
  Completer<String>? pendingSignIn;
  int anonymousSignInCount = 0;

  @override
  Future<String> signInAnonymously() async {
    anonymousSignInCount += 1;
    final error = signInError;
    if (error != null) {
      throw error;
    }
    final pending = pendingSignIn;
    if (pending != null) {
      return pending.future;
    }
    return 'anonymous-user';
  }
}

class _FakeProfileRepository implements ProfileRepository {
  Object? upsertError;
  Object? loadError;

  @override
  Future<void> upsert(String userId) async {
    final error = upsertError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<UserProfile> load(String userId) async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return UserProfile(
      id: userId,
      displayName: null,
      createdAt: DateTime.utc(2026, 6, 28),
      updatedAt: DateTime.utc(2026, 6, 28),
    );
  }
}

class _TrackingEventsRepository implements EventsRepository {
  _TrackingEventsRepository({this.cachedSnapshot, this.remoteError});

  final EventSnapshot? cachedSnapshot;
  final Object? remoteError;
  int loadCount = 0;

  @override
  Future<void> cacheEvents(List<Event> events) async {}

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<void> updateEvent(Event event) async {}

  @override
  Future<void> cancelEvent(String eventId) async {}

  @override
  Future<EventSnapshot?> getCachedEvents() async => cachedSnapshot;

  @override
  Future<Event?> getEventById(String id) async => null;

  @override
  Future<List<Event>> getEvents() async {
    loadCount += 1;
    final error = remoteError;
    if (error != null) {
      throw error;
    }
    return const [];
  }

  @override
  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {}
}

final _cachedEvent = Event(
  id: 'offline-snapshot-event',
  title: 'Offline Snapshot Meet',
  description: 'Visible while profile and event refresh are offline.',
  locationName: 'Saved Garage',
  hostName: 'Saved Host',
  startTime: DateTime.utc(2026, 7, 1, 18),
  endTime: DateTime.utc(2026, 7, 1, 20),
  attendeeCount: 3,
  viewerRsvpStatus: RsvpStatus.interested,
);
