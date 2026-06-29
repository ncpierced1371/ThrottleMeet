import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/identity/participant_id_store.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_snapshot.dart';
import '../../domain/entities/rsvp_status.dart';
import '../../domain/repositories/events_repository.dart';
import '../cache/event_snapshot_cache.dart';
import '../models/event_record.dart';
import 'supabase_error_mapper.dart';

class SupabaseEventsRepository implements EventsRepository {
  SupabaseEventsRepository({
    required ParticipantIdStore participantIdStore,
    SupabaseClient? client,
    EventSnapshotCache? eventSnapshotCache,
    Duration requestTimeout = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _participantIdStore = participantIdStore,
       _client = client ?? Supabase.instance.client,
       _eventSnapshotCache = eventSnapshotCache,
       _now = now ?? DateTime.now,
       _requestTimeout = requestTimeout;

  final ParticipantIdStore _participantIdStore;
  final SupabaseClient _client;
  final EventSnapshotCache? _eventSnapshotCache;
  final DateTime Function() _now;
  final Duration _requestTimeout;

  @override
  Future<EventSnapshot?> getCachedEvents() async {
    final cache = _eventSnapshotCache;
    if (cache == null) {
      return null;
    }

    final participantId = await _participantIdStore.getOrCreateParticipantId();
    return cache.read(participantId);
  }

  @override
  Future<void> createEvent(Event event) {
    return _execute('createEvent', () async {
      final record = EventRecord.fromEntity(event);
      await _client.from('events').insert(record.toCreateMap());
      debugPrint('SupabaseEventsRepository.createEvent success: ${event.id}');
    });
  }

  @override
  Future<Event?> getEventById(String id) {
    return _execute('getEventById', () async {
      final participantId = await _participantIdStore
          .getOrCreateParticipantId();
      final data = await _client
          .rpc(
            'get_events_for_participant',
            params: {'participant_id': participantId},
          )
          .eq('id', id)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return EventRecord.fromMap(data).toEntity();
    });
  }

  @override
  Future<List<Event>> getEvents() async {
    final result = await _execute('getEvents', () async {
      final participantId = await _participantIdStore
          .getOrCreateParticipantId();
      final data = await _client
          .rpc(
            'get_events_for_participant',
            params: {'participant_id': participantId},
          )
          .select();

      debugPrint(
        'SupabaseEventsRepository.getEvents rows returned: ${data.length}',
      );

      final events = data
          .map<Event>((item) => EventRecord.fromMap(item).toEntity())
          .toList();
      return (participantId: participantId, events: events);
    });

    final cache = _eventSnapshotCache;
    if (cache != null) {
      try {
        await cache.write(
          result.participantId,
          EventSnapshot(events: result.events, cachedAt: _now().toUtc()),
        );
      } catch (error) {
        debugPrint('Unable to cache refreshed events: $error');
      }
    }

    return result.events;
  }

  @override
  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) {
    return _execute('updateRsvp', () async {
      final participantId = await _participantIdStore
          .getOrCreateParticipantId();
      final savedStatus = await _client.rpc<String>(
        'set_event_rsvp',
        params: {
          'event_id': eventId,
          'participant_id': participantId,
          'status': status.name,
        },
      );

      if (savedStatus != status.name) {
        throw StateError(
          'RSVP update returned "$savedStatus" instead of "${status.name}".',
        );
      }
    });
  }

  Future<T> _execute<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    try {
      return await Future<T>.sync(operation).timeout(_requestTimeout);
    } catch (error, stackTrace) {
      final appException = SupabaseErrorMapper.map(error);
      debugPrint(
        'SupabaseEventsRepository.$operationName error: $appException',
      );
      Error.throwWithStackTrace(appException, stackTrace);
    }
  }
}
