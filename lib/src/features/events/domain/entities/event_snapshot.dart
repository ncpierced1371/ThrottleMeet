import 'event.dart';

class EventSnapshot {
  EventSnapshot({required List<Event> events, required this.cachedAt})
    : events = List.unmodifiable(events);

  final List<Event> events;
  final DateTime cachedAt;
}
