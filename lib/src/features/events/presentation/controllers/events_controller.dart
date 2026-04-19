import 'package:flutter/foundation.dart';

import '../../domain/entities/event.dart';
import '../../domain/entities/rsvp_status.dart';
import '../../domain/usecases/create_event.dart';
import '../../domain/usecases/get_event_by_id.dart';
import '../../domain/usecases/get_events.dart';
import '../../domain/usecases/update_rsvp.dart';

class EventsController extends ChangeNotifier {
  EventsController({
    required GetEvents getEvents,
    required GetEventById getEventById,
    required CreateEvent createEvent,
    required UpdateRsvp updateRsvp,
  }) : _getEvents = getEvents,
       _getEventById = getEventById,
       _createEvent = createEvent,
       _updateRsvp = updateRsvp;

  final GetEvents _getEvents;
  final GetEventById _getEventById;
  final CreateEvent _createEvent;
  final UpdateRsvp _updateRsvp;

  final List<Event> _events = [];

  bool _isLoading = false;

  List<Event> get events => List.unmodifiable(_events);

  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final items = await _getEvents();
    _events
      ..clear()
      ..addAll(items);

    _isLoading = false;
    notifyListeners();
  }

  Event? eventById(String id) {
    try {
      return _events.firstWhere((event) => event.id == id);
    } on StateError {
      return null;
    }
  }

  Future<Event?> refreshEvent(String id) async {
    final event = await _getEventById(id);

    if (event == null) {
      return null;
    }

    final index = _events.indexWhere((item) => item.id == id);
    if (index == -1) {
      _events.add(event);
    } else {
      _events[index] = event;
    }

    _events.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    notifyListeners();

    return event;
  }

  Future<void> createNewEvent({
    required String title,
    required String description,
    required String location,
    required String hostName,
    required DateTime scheduledAt,
  }) async {
    final event = Event(
      id: _buildId(title, scheduledAt),
      title: title,
      description: description,
      location: location,
      hostName: hostName,
      scheduledAt: scheduledAt,
      rsvpStatus: RsvpStatus.going,
    );

    await _createEvent(event);
    await load();
  }

  Future<void> setRsvpStatus({
    required String eventId,
    required RsvpStatus status,
  }) async {
    await _updateRsvp(eventId: eventId, status: status);
    await refreshEvent(eventId);
  }

  String _buildId(String title, DateTime scheduledAt) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    return '$slug-${scheduledAt.millisecondsSinceEpoch}';
  }
}
