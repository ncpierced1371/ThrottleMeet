import '../../domain/entities/event.dart';
import '../../domain/entities/event_snapshot.dart';
import '../../domain/entities/rsvp_status.dart';
import '../../domain/repositories/events_repository.dart';
import '../seeds/seed_events.dart';

class InMemoryEventsRepository implements EventsRepository {
  InMemoryEventsRepository() : _events = SeedEvents.build();

  final List<Event> _events;

  @override
  Future<EventSnapshot?> getCachedEvents() async => null;

  @override
  Future<void> cacheEvents(List<Event> events) async {}

  @override
  Future<void> createEvent(Event event) async {
    _events.insert(0, event);
  }

  @override
  Future<void> updateEvent(Event event) async {
    final index = _events.indexWhere((existing) => existing.id == event.id);
    if (index != -1) {
      _events[index] = event;
    }
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    final index = _events.indexWhere((event) => event.id == eventId);
    if (index != -1) {
      _events[index] = _events[index].copyWith(
        status: EventStatus.cancelled,
        cancelledAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Future<Event?> getEventById(String id) async {
    try {
      return _events.firstWhere((event) => event.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<List<Event>> getEvents() async {
    final events = [..._events];
    events.sort((a, b) => a.startTime.compareTo(b.startTime));
    return events;
  }

  @override
  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {
    final index = _events.indexWhere((event) => event.id == eventId);

    if (index == -1) {
      return;
    }

    _events[index] = _events[index].copyWith(viewerRsvpStatus: status);
  }
}
