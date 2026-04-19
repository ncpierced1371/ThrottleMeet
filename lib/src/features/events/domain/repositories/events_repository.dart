import '../entities/event.dart';
import '../entities/rsvp_status.dart';

abstract class EventsRepository {
  Future<List<Event>> getEvents();

  Future<Event?> getEventById(String id);

  Future<void> createEvent(Event event);

  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  });
}
