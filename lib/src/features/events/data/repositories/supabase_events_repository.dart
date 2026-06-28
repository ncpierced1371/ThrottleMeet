import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/event.dart';
import '../../domain/entities/rsvp_status.dart';
import '../../domain/repositories/events_repository.dart';
import '../models/event_record.dart';

class SupabaseEventsRepository implements EventsRepository {
  SupabaseEventsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<void> createEvent(Event event) async {
    try {
      final record = EventRecord.fromEntity(event);
      await _client.from('events').insert(record.toMap());
      debugPrint('SupabaseEventsRepository.createEvent success: ${event.id}');
    } catch (error) {
      debugPrint('SupabaseEventsRepository.createEvent error: $error');
      rethrow;
    }
  }

  @override
  Future<Event?> getEventById(String id) async {
    final data = await _client
        .from('events')
        .select(
          'id, title, description, location_name, host_name, start_time, end_time, attendee_count, rsvp_status',
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
      final data = await _client
          .from('events')
          .select(
            'id, title, description, location_name, host_name, start_time, end_time, attendee_count, rsvp_status',
          )
          .order('start_time');

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
    await _client
        .from('events')
        .update({
          'rsvp_status': status.name,
        })
        .eq('id', eventId);
  }
}
