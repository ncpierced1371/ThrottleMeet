import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:throttlemeet_v2/src/core/identity/participant_id_store.dart';
import 'package:throttlemeet_v2/src/features/events/data/repositories/supabase_events_repository.dart';
import 'package:throttlemeet_v2/src/features/events/domain/entities/rsvp_status.dart';

void main() {
  const participantId = 'participant-123';

  group('SupabaseEventsRepository', () {
    test(
      'getEvents requests the participant RPC and maps attendee and RSVP data',
      () async {
        late Request request;
        final store = _TrackingParticipantIdStore(participantId);
        final client = _clientWith((receivedRequest) async {
          request = receivedRequest;
          return _jsonResponse(receivedRequest, [
            _eventRow(id: 'event-1', attendeeCount: 12, rsvpStatus: 'going'),
            _eventRow(id: 'event-2', attendeeCount: 3, rsvpStatus: null),
          ]);
        });
        addTearDown(client.dispose);
        final repository = SupabaseEventsRepository(
          participantIdStore: store,
          client: client,
        );

        final events = await repository.getEvents();

        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/rpc/get_events_for_participant');
        expect(jsonDecode(request.body), {'participant_id': participantId});
        expect(store.requestCount, 1);
        expect(events, hasLength(2));
        expect(events[0].attendeeCount, 12);
        expect(events[0].viewerRsvpStatus, RsvpStatus.going);
        expect(events[1].attendeeCount, 3);
        expect(events[1].viewerRsvpStatus, isNull);
      },
    );

    test(
      'getEventById requests the participant RPC with an ID filter',
      () async {
        late Request request;
        final store = _TrackingParticipantIdStore(participantId);
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
          participantIdStore: store,
          client: client,
        );

        final event = await repository.getEventById('event-42');

        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/rpc/get_events_for_participant');
        expect(request.url.queryParameters['id'], 'eq.event-42');
        expect(jsonDecode(request.body), {'participant_id': participantId});
        expect(store.requestCount, 1);
        expect(event?.id, 'event-42');
        expect(event?.attendeeCount, 8);
        expect(event?.viewerRsvpStatus, RsvpStatus.interested);
      },
    );

    test(
      'updateRsvp requests set_event_rsvp with participant and RSVP',
      () async {
        late Request request;
        final store = _TrackingParticipantIdStore(participantId);
        final client = _clientWith((receivedRequest) async {
          request = receivedRequest;
          return _jsonResponse(receivedRequest, 'notGoing');
        });
        addTearDown(client.dispose);
        final repository = SupabaseEventsRepository(
          participantIdStore: store,
          client: client,
        );

        await repository.updateRsvp(
          eventId: 'event-7',
          status: RsvpStatus.notGoing,
        );

        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/rpc/set_event_rsvp');
        expect(jsonDecode(request.body), {
          'event_id': 'event-7',
          'participant_id': participantId,
          'status': 'notGoing',
        });
        expect(store.requestCount, 1);
      },
    );

    test(
      'updateRsvp throws when the RPC returns a mismatched status',
      () async {
        final store = _TrackingParticipantIdStore(participantId);
        final client = _clientWith(
          (request) async => _jsonResponse(request, 'interested'),
        );
        addTearDown(client.dispose);
        final repository = SupabaseEventsRepository(
          participantIdStore: store,
          client: client,
        );

        await expectLater(
          repository.updateRsvp(eventId: 'event-7', status: RsvpStatus.going),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('interested'),
            ),
          ),
        );
        expect(store.requestCount, 1);
      },
    );
  });
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
  };
}

class _TrackingParticipantIdStore extends ParticipantIdStore {
  _TrackingParticipantIdStore(this.participantId);

  final String participantId;
  int requestCount = 0;

  @override
  Future<String> getOrCreateParticipantId() async {
    requestCount += 1;
    return participantId;
  }
}
