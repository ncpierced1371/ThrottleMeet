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
    final record = EventRecord.fromEntity(event);
    await _client.from('events').insert(record.toMap());
  }

  @override
  Future<Event?> getEventById(String id) async {
    final data = await _client
        .from('events')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return EventRecord.fromMap(data).toEntity();
  }

  @override
  Future<List<Event>> getEvents() async {
    final data = await _client
        .from('events')
        .select()
        .order('start_time');

    return data
        .map<Event>((item) => EventRecord.fromMap(item).toEntity())
        .toList();
  }

  @override
  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {
    await _client
        .from('events')
        .update({'rsvp_status': status.name})
        .eq('id', eventId);
  }
}
