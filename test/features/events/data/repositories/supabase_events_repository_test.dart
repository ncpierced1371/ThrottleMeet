import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:throttlemeet_v2/src/core/errors/app_exception.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/repositories/auth_session_provider.dart';
import 'package:throttlemeet_v2/src/features/events/data/cache/event_snapshot_cache.dart';
import 'package:throttlemeet_v2/src/features/events/data/repositories/supabase_events_repository.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/event.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/event_snapshot.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/rsvp_status.dart';

void main() {
  const userId = 'authenticated-user-123';

  group('SupabaseEventsRepository', () {
    test('createEvent atomically creates the event and creator RSVP', () async {
      late Request request;
      final event = _event(id: 'new-event');
      final client = _clientWith((receivedRequest) async {
        request = receivedRequest;
        return _jsonResponse(receivedRequest, {
          'id': event.id,
          'attendee_count': 1,
          'rsvp_status': 'going',
        });
      });
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(userId),
        client: client,
      );

      await repository.createEvent(event);

      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/rest/v1/rpc/create_event_with_creator_rsvp_v2',
      );
      expect(jsonDecode(request.body), {
        'event_id': 'new-event',
        'title': 'Test Meet',
        'description': 'A test event.',
        'location_name': 'Test Garage',
        'host_name': 'Test Host',
        'start_time': '2026-07-01T18:00:00.000Z',
        'end_time': '2026-07-01T20:00:00.000Z',
      });
      expect(request.body, isNot(contains('participant_id')));
      expect(request.body, isNot(contains('user_id')));
    });

    test('createEvent rejects a mismatched RPC confirmation', () async {
      final event = _event(id: 'new-event');
      final client = _clientWith(
        (request) async => _jsonResponse(request, {
          'id': event.id,
          'attendee_count': 0,
          'rsvp_status': null,
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(userId),
        client: client,
      );

      await expectLater(
        repository.createEvent(event),
        _throwsAppError(AppErrorType.validationOrServer),
      );
    });

    test('updateEvent uses update_event_v2 without caller identity', () async {
      late Request request;
      final event = _event(
        id: 'owned-event',
      ).copyWith(title: 'Updated Meet', description: 'Updated description.');
      final client = _clientWith((receivedRequest) async {
        request = receivedRequest;
        return _jsonResponse(receivedRequest, {
          'id': event.id,
          'title': event.title,
          'description': event.description,
          'location_name': event.locationName,
          'host_name': event.hostName,
          'start_time': event.startTime.toIso8601String(),
          'end_time': event.endTime.toIso8601String(),
          'updated_at': '2026-06-30T12:00:00Z',
        });
      });
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(userId),
        client: client,
      );

      await repository.updateEvent(event);

      expect(request.url.path, '/rest/v1/rpc/update_event_v2');
      expect(jsonDecode(request.body), {
        'event_id': 'owned-event',
        'title': 'Updated Meet',
        'description': 'Updated description.',
        'location_name': 'Test Garage',
        'host_name': 'Test Host',
        'start_time': '2026-07-01T18:00:00.000Z',
        'end_time': '2026-07-01T20:00:00.000Z',
      });
      expect(request.body, isNot(contains('user_id')));
      expect(request.body, isNot(contains('participant_id')));
      expect(request.body, isNot(contains('creator_id')));
      expect(request.body, isNot(contains('is_owner')));
    });

    test('cancelEvent uses cancel_event_v2 without caller identity', () async {
      late Request request;
      final client = _clientWith((receivedRequest) async {
        request = receivedRequest;
        return _jsonResponse(receivedRequest, {
          'id': 'owned-event',
          'status': 'cancelled',
          'cancelled_at': '2026-06-30T12:00:00Z',
        });
      });
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(userId),
        client: client,
      );

      await repository.cancelEvent('owned-event');

      expect(request.url.path, '/rest/v1/rpc/cancel_event_v2');
      expect(jsonDecode(request.body), {'event_id': 'owned-event'});
      expect(request.body, isNot(contains('user_id')));
      expect(request.body, isNot(contains('participant_id')));
    });

    test(
      'getEvents requests the current-user RPC and maps attendee and RSVP data',
      () async {
        late Request request;
        final client = _clientWith((receivedRequest) async {
          request = receivedRequest;
          return _jsonResponse(receivedRequest, [
            _eventRow(id: 'event-1', attendeeCount: 12, rsvpStatus: 'going'),
            _eventRow(id: 'event-2', attendeeCount: 3, rsvpStatus: null),
          ]);
        });
        addTearDown(client.dispose);
        final repository = SupabaseEventsRepository(
          authSessionProvider: const _FakeAuthSessionProvider(userId),
          client: client,
        );

        final events = await repository.getEvents();

        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/rpc/get_events_for_current_user');
        expect(jsonDecode(request.body), isNull);
        expect(request.body, isNot(contains('participant_id')));
        expect(request.body, isNot(contains('user_id')));
        expect(events, hasLength(2));
        expect(events[0].attendeeCount, 12);
        expect(events[0].viewerRsvpStatus, RsvpStatus.going);
        expect(events[1].attendeeCount, 3);
        expect(events[1].viewerRsvpStatus, isNull);
      },
    );

    test(
      'getEventById requests the current-user RPC with an ID filter',
      () async {
        late Request request;
        final client = _clientWith((receivedRequest) async {
          request = receivedRequest;
          return _jsonResponse(
            receivedRequest,
            _eventRow(
              id: 'event-42',
              attendeeCount: 8,
              rsvpStatus: 'interested',
            ),
          );
        });
        addTearDown(client.dispose);
        final repository = SupabaseEventsRepository(
          authSessionProvider: const _FakeAuthSessionProvider(userId),
          client: client,
        );

        final event = await repository.getEventById('event-42');

        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/rpc/get_events_for_current_user');
        expect(request.url.queryParameters['id'], 'eq.event-42');
        expect(jsonDecode(request.body), isNull);
        expect(request.body, isNot(contains('participant_id')));
        expect(request.body, isNot(contains('user_id')));
        expect(event?.id, 'event-42');
        expect(event?.attendeeCount, 8);
        expect(event?.viewerRsvpStatus, RsvpStatus.interested);
      },
    );

    test(
      'getEventRsvpsForOwner uses owner RPC and maps limited profile fields',
      () async {
        late Request request;
        final client = _clientWith((receivedRequest) async {
          request = receivedRequest;
          return _jsonResponse(receivedRequest, [
            {
              'user_id': 'user-a',
              'display_name': 'Avery Driver',
              'avatar_url': 'https://example.com/avery.jpg',
              'status': 'going',
              'updated_at': '2026-07-01T12:00:00Z',
            },
            {
              'user_id': 'user-b',
              'display_name': null,
              'avatar_url': null,
              'status': 'notGoing',
              'updated_at': '2026-07-01T13:00:00Z',
            },
          ]);
        });
        addTearDown(client.dispose);
        final repository = SupabaseEventsRepository(
          authSessionProvider: const _FakeAuthSessionProvider(userId),
          client: client,
        );

        final attendees = await repository.getEventRsvpsForOwner('event-42');

        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/rpc/get_event_rsvps_for_owner_v1');
        expect(jsonDecode(request.body), {'event_id': 'event-42'});
        expect(request.body, isNot(contains('participant_id')));
        expect(request.body, isNot(contains('user_id')));
        expect(attendees, hasLength(2));
        expect(attendees.first.userId, 'user-a');
        expect(attendees.first.displayName, 'Avery Driver');
        expect(attendees.first.avatarUrl, 'https://example.com/avery.jpg');
        expect(attendees.first.status, RsvpStatus.going);
        expect(attendees.first.updatedAt, DateTime.utc(2026, 7, 1, 12));
        expect(attendees.last.displayName, isNull);
        expect(attendees.last.avatarUrl, isNull);
        expect(attendees.last.status, RsvpStatus.notGoing);
      },
    );

    test('getEventRsvpsForOwner rejects an unknown RSVP status', () async {
      final client = _clientWith(
        (request) async => _jsonResponse(request, [
          {
            'user_id': 'user-a',
            'display_name': 'Avery Driver',
            'avatar_url': null,
            'status': 'maybe',
            'updated_at': '2026-07-01T12:00:00Z',
          },
        ]),
      );
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(userId),
        client: client,
      );

      await expectLater(
        repository.getEventRsvpsForOwner('event-42'),
        _throwsAppError(AppErrorType.validationOrServer),
      );
    });

    test(
      'accepted remote refresh replaces the authenticated user cache',
      () async {
        final cachedAt = DateTime.utc(2026, 6, 28, 12);
        final cache = _FakeEventSnapshotCache();
        final client = _clientWith(
          (request) async => _jsonResponse(request, [
            _eventRow(
              id: 'refreshed-event',
              attendeeCount: 5,
              rsvpStatus: null,
            ),
          ]),
        );
        addTearDown(client.dispose);
        final repository = SupabaseEventsRepository(
          authSessionProvider: const _FakeAuthSessionProvider(userId),
          client: client,
          eventSnapshotCache: cache,
          now: () => cachedAt,
        );

        final events = await repository.getEvents();
        await repository.cacheEvents(events);

        expect(events.single.id, 'refreshed-event');
        expect(cache.userId, userId);
        expect(cache.snapshot?.events.single.id, 'refreshed-event');
        expect(cache.snapshot?.events.single.viewerRsvpStatus, isNull);
        expect(cache.snapshot?.cachedAt, cachedAt);
      },
    );

    test('cached events use only the authenticated user cache key', () async {
      final snapshot = EventSnapshot(
        events: [_event(id: 'cached-event')],
        cachedAt: DateTime.utc(2026, 6, 29, 12),
      );
      final cache = _FakeEventSnapshotCache()
        ..userId = userId
        ..snapshot = snapshot;
      final client = _clientWith(
        (request) async => _jsonResponse(request, const []),
      );
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(userId),
        client: client,
        eventSnapshotCache: cache,
      );

      final cached = await repository.getCachedEvents();

      expect(cache.lastReadUserId, userId);
      expect(cached, same(snapshot));
    });

    test(
      'updateRsvp requests set_event_rsvp_v2 without caller identity',
      () async {
        late Request request;
        final client = _clientWith((receivedRequest) async {
          request = receivedRequest;
          return _jsonResponse(receivedRequest, 'notGoing');
        });
        addTearDown(client.dispose);
        final repository = SupabaseEventsRepository(
          authSessionProvider: const _FakeAuthSessionProvider(userId),
          client: client,
        );

        await repository.updateRsvp(
          eventId: 'event-7',
          status: RsvpStatus.notGoing,
        );

        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/rpc/set_event_rsvp_v2');
        expect(jsonDecode(request.body), {
          'event_id': 'event-7',
          'status': 'notGoing',
        });
        expect(request.body, isNot(contains('participant_id')));
        expect(request.body, isNot(contains('user_id')));
      },
    );

    test(
      'updateRsvp throws when the RPC returns a mismatched status',
      () async {
        final client = _clientWith(
          (request) async => _jsonResponse(request, 'interested'),
        );
        addTearDown(client.dispose);
        final repository = SupabaseEventsRepository(
          authSessionProvider: const _FakeAuthSessionProvider(userId),
          client: client,
        );

        await expectLater(
          repository.updateRsvp(eventId: 'event-7', status: RsvpStatus.going),
          throwsA(
            isA<AppException>()
                .having(
                  (error) => error.type,
                  'type',
                  AppErrorType.validationOrServer,
                )
                .having(
                  (error) => error.cause.toString(),
                  'cause',
                  contains('interested'),
                ),
          ),
        );
      },
    );

    test('maps socket failures to network errors', () async {
      final client = _clientWith(
        (_) async => throw const SocketException('Network unreachable'),
      );
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(userId),
        client: client,
      );

      await expectLater(
        repository.getEvents(),
        _throwsAppError(AppErrorType.network),
      );
    });

    test('maps request timeouts to timeout errors', () async {
      final client = _clientWith((_) => Completer<Response>().future);
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(userId),
        client: client,
        requestTimeout: Duration.zero,
      );

      await expectLater(
        repository.getEvents(),
        _throwsAppError(AppErrorType.timeout),
      );
    });

    test(
      'maps PostgREST permission failures to authorization errors',
      () async {
        final client = _clientWith(
          (request) async =>
              _postgrestErrorResponse(request, statusCode: 403, code: '42501'),
        );
        addTearDown(client.dispose);
        final repository = SupabaseEventsRepository(
          authSessionProvider: const _FakeAuthSessionProvider(userId),
          client: client,
        );

        await expectLater(
          repository.getEvents(),
          _throwsAppError(AppErrorType.authorization),
        );
      },
    );

    test('maps Supabase auth failures to authorization errors', () async {
      final client = _clientWith(
        (_) async => throw const AuthException('Invalid session'),
      );
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(userId),
        client: client,
      );

      await expectLater(
        repository.getEvents(),
        _throwsAppError(AppErrorType.authorization),
      );
    });

    test('maps PostgREST validation failures to server errors', () async {
      final client = _clientWith(
        (request) async =>
            _postgrestErrorResponse(request, statusCode: 400, code: '23514'),
      );
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(userId),
        client: client,
      );

      await expectLater(
        repository.getEvents(),
        _throwsAppError(AppErrorType.validationOrServer),
      );
    });

    test('maps unrecognized failures to unknown errors', () async {
      final client = _clientWith(
        (_) async => throw Exception('Unexpected failure'),
      );
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(userId),
        client: client,
      );

      await expectLater(
        repository.getEvents(),
        _throwsAppError(AppErrorType.unknown),
      );
    });

    test('fails clearly before a request when no auth user exists', () async {
      var requestCount = 0;
      final client = _clientWith((request) async {
        requestCount += 1;
        return _jsonResponse(request, const []);
      });
      addTearDown(client.dispose);
      final repository = SupabaseEventsRepository(
        authSessionProvider: const _FakeAuthSessionProvider(null),
        client: client,
      );

      await expectLater(
        repository.getEvents(),
        throwsA(
          isA<AppException>()
              .having((error) => error.type, 'type', AppErrorType.authorization)
              .having(
                (error) => error.cause.toString(),
                'cause',
                contains('active authenticated Supabase user'),
              ),
        ),
      );
      expect(requestCount, 0);
    });
  });
}

Matcher _throwsAppError(AppErrorType type) {
  return throwsA(
    isA<AppException>().having((error) => error.type, 'type', type),
  );
}

Response _postgrestErrorResponse(
  Request request, {
  required int statusCode,
  required String code,
}) {
  return Response(
    jsonEncode({
      'message': 'Fake PostgREST failure',
      'code': code,
      'details': null,
      'hint': null,
    }),
    statusCode,
    request: request,
    headers: {'content-type': 'application/json'},
  );
}

SupabaseClient _clientWith(MockClientHandler handler) {
  return SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: MockClient(handler),
  );
}

Response _jsonResponse(Request request, Object? body) {
  return Response(
    jsonEncode(body),
    200,
    request: request,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _eventRow({
  required String id,
  required int attendeeCount,
  required String? rsvpStatus,
  String status = 'active',
  bool isOwner = false,
  String? cancelledAt,
}) {
  return {
    'id': id,
    'title': 'Test Meet',
    'description': 'A test event.',
    'location_name': 'Test Garage',
    'host_name': 'Test Host',
    'start_time': '2026-07-01T18:00:00Z',
    'end_time': '2026-07-01T20:00:00Z',
    'attendee_count': attendeeCount,
    'rsvp_status': rsvpStatus,
    'status': status,
    'is_owner': isOwner,
    'cancelled_at': cancelledAt,
  };
}

Event _event({required String id}) {
  return Event(
    id: id,
    title: 'Test Meet',
    description: 'A test event.',
    locationName: 'Test Garage',
    hostName: 'Test Host',
    startTime: DateTime.utc(2026, 7, 1, 18),
    endTime: DateTime.utc(2026, 7, 1, 20),
    attendeeCount: 0,
    viewerRsvpStatus: RsvpStatus.going,
  );
}

class _FakeAuthSessionProvider implements AuthSessionProvider {
  const _FakeAuthSessionProvider(this.currentUserId);

  @override
  final String? currentUserId;
}

class _FakeEventSnapshotCache implements EventSnapshotCache {
  String? userId;
  String? lastReadUserId;
  EventSnapshot? snapshot;

  @override
  Future<EventSnapshot?> read(String userId) async {
    lastReadUserId = userId;
    return this.userId == userId ? snapshot : null;
  }

  @override
  Future<void> write(String userId, EventSnapshot snapshot) async {
    this.userId = userId;
    this.snapshot = snapshot;
  }
}
