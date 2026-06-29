import '../entities/event.dart';
import '../entities/event_snapshot.dart';
import '../entities/rsvp_status.dart';

abstract class EventsRepository {
  Future<EventSnapshot?> getCachedEvents();

  Future<List<Event>> getEvents();

  Future<Event?> getEventById(String id);

  Future<void> createEvent(Event event);

  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  });
}
