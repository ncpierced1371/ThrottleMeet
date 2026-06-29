import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/rsvp_status.dart';
import '../../domain/repositories/events_repository.dart';

class EventsController extends ChangeNotifier {
  EventsController({required EventsRepository repository})
    : _repository = repository;

  final EventsRepository _repository;

  List<Event> _events = [];
  bool _isLoading = false;
  String? _errorMessage;
  AppErrorType? _errorType;

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AppErrorType? get errorType => _errorType;

  Future<bool> loadEvents() async {
    _isLoading = true;
    _errorMessage = null;
    _errorType = null;
    notifyListeners();

    try {
      _events = await _repository.getEvents();
      return true;
    } catch (error) {
      debugPrint('EventsController.loadEvents error: $error');
      _recordError(error, fallbackMessage: 'Unable to load events.');
      return false;
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

  Future<bool> createNewEvent(Event event) async {
    try {
      await _repository.createEvent(event);
    } catch (error) {
      debugPrint('EventsController.createNewEvent error: $error');
      _recordError(error, fallbackMessage: 'Unable to create event.');
      notifyListeners();
      return false;
    }

    return loadEvents();
  }

  Future<bool> updateRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {
    try {
      await _repository.updateRsvp(eventId: eventId, status: status);
    } catch (error) {
      debugPrint('EventsController.updateRsvp error: $error');
      _recordError(error, fallbackMessage: 'Unable to update RSVP.');
      notifyListeners();
      return false;
    }

    return loadEvents();
  }

  void _recordError(Object error, {required String fallbackMessage}) {
    final appException = error is AppException
        ? error
        : AppException(type: AppErrorType.unknown, cause: error);
    _errorType = appException.type;
    _errorMessage = switch (appException.type) {
      AppErrorType.network =>
        'No network connection. Check your connection and try again.',
      AppErrorType.timeout => 'The request timed out. Please try again.',
      AppErrorType.authorization =>
        'You do not have permission to perform this action.',
      AppErrorType.validationOrServer =>
        'The server could not complete the request. Please try again.',
      AppErrorType.unknown => fallbackMessage,
    };
  }
}
