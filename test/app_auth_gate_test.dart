import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/app.dart';
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
  testWidgets('does not construct or load events before auth is ready', (
    tester,
  ) async {
    final authGateway = _PendingAuthGateway();
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

    authGateway.complete('authenticated-user');
    await tester.pumpAndSettle();

    expect(authController.state, AuthBootstrapState.ready);
    expect(eventsControllerCreationCount, 1);
    expect(eventsRepository.loadCount, 1);
  });
}

class _PendingAuthGateway implements AuthGateway {
  final Completer<String> _signInCompleter = Completer<String>();

  @override
  String? get currentUserId => null;

  @override
  Future<String> signInAnonymously() => _signInCompleter.future;

  void complete(String userId) => _signInCompleter.complete(userId);
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<void> upsert(String userId) async {}

  @override
  Future<UserProfile> load(String userId) async {
    return UserProfile(
      id: userId,
      displayName: null,
      createdAt: DateTime.utc(2026, 6, 28),
      updatedAt: DateTime.utc(2026, 6, 28),
    );
  }
}

class _TrackingEventsRepository implements EventsRepository {
  int loadCount = 0;

  @override
  Future<void> cacheEvents(List<Event> events) async {}

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<EventSnapshot?> getCachedEvents() async => null;

  @override
  Future<Event?> getEventById(String id) async => null;

  @override
  Future<List<Event>> getEvents() async {
    loadCount += 1;
    return const [];
  }

  @override
  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {}
}
