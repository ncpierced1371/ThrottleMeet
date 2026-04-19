import 'package:flutter/foundation.dart';

import '../../domain/entities/event.dart';
import '../../domain/entities/rsvp_status.dart';
import '../../domain/repositories/events_repository.dart';

class EventsController extends ChangeNotifier {
  EventsController({
    required EventsRepository repository,
  }) : _repository = repository;

  final EventsRepository _repository;

  List<Event> _events = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadEvents() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _events = await _repository.getEvents();
    } catch (_) {
      _errorMessage = 'Unable to load events.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Event? getEventById(String id) {
    try {
      return _events.firstWhere((event) => event.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> createNewEvent(Event event) async {
    try {
      await _repository.createEvent(event);
      await loadEvents();
    } catch (_) {
      _errorMessage = 'Unable to create event.';
      notifyListeners();
    }
  }

  Future<void> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {
    try {
      await _repository.updateRsvp(eventId: eventId, status: status);
      await loadEvents();
    } catch (_) {
      _errorMessage = 'Unable to update RSVP.';
      notifyListeners();
    }
  }
}
