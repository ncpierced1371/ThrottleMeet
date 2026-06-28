import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/identity/participant_id_store.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/rsvp_status.dart';
import '../../domain/repositories/events_repository.dart';
import '../models/event_record.dart';

class SupabaseEventsRepository implements EventsRepository {
  SupabaseEventsRepository({
    required ParticipantIdStore participantIdStore,
    SupabaseClient? client,
  }) : _participantIdStore = participantIdStore,
       _client = client ?? Supabase.instance.client;

  final ParticipantIdStore _participantIdStore;
  final SupabaseClient _client;

  @override
  Future<void> createEvent(Event event) async {
    try {
      final record = EventRecord.fromEntity(event);
      await _client.from('events').insert(record.toCreateMap());
      debugPrint('SupabaseEventsRepository.createEvent success: ${event.id}');
    } catch (error) {
      debugPrint('SupabaseEventsRepository.createEvent error: $error');
      rethrow;
    }
  }

  @override
  Future<Event?> getEventById(String id) async {
    final participantId = await _participantIdStore.getOrCreateParticipantId();
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
  }

  @override
  Future<List<Event>> getEvents() async {
    try {
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

      return data
          .map<Event>((item) => EventRecord.fromMap(item).toEntity())
          .toList();
    } catch (error) {
      debugPrint('SupabaseEventsRepository.getEvents error: $error');
      rethrow;
    }
  }

  @override
  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {
    final participantId = await _participantIdStore.getOrCreateParticipantId();
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
  }
}
