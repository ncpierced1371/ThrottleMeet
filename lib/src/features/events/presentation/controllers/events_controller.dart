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
  bool _isShowingCachedEvents = false;
  DateTime? _cachedAt;
  int _loadGeneration = 0;
  Future<void> _cacheWriteQueue = Future.value();

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AppErrorType? get errorType => _errorType;
  bool get isShowingCachedEvents => _isShowingCachedEvents;
  DateTime? get cachedAt => _cachedAt;

  Future<bool> loadEvents() async {
    final generation = ++_loadGeneration;
    _isLoading = true;
    _errorMessage = null;
    _errorType = null;
    notifyListeners();

    try {
      if (_events.isEmpty) {
        try {
          final snapshot = await _repository.getCachedEvents();
          if (!_isCurrentLoad(generation)) {
            return false;
          }
          if (snapshot != null) {
            _events = snapshot.events;
            _isShowingCachedEvents = true;
            _cachedAt = snapshot.cachedAt;
            notifyListeners();
          }
        } catch (error) {
          if (!_isCurrentLoad(generation)) {
            return false;
          }
          debugPrint('EventsController cached event load error: $error');
        }
      }

      final events = await _repository.getEvents();
      if (!_isCurrentLoad(generation)) {
        return false;
      }

      _events = events;
      _isShowingCachedEvents = false;
      _cachedAt = null;
      notifyListeners();

      await _queueCacheWrite(events);
      return _isCurrentLoad(generation);
    } catch (error) {
      if (!_isCurrentLoad(generation)) {
        return false;
      }
      debugPrint('EventsController.loadEvents error: $error');
      _recordError(error, fallbackMessage: 'Unable to load events.');
      return false;
    } finally {
      if (_isCurrentLoad(generation)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentLoad(int generation) => generation == _loadGeneration;

  Future<void> _queueCacheWrite(List<Event> events) async {
    final previousWrite = _cacheWriteQueue;
    final write = () async {
      await previousWrite;
      try {
        await _repository.cacheEvents(events);
      } catch (error) {
        debugPrint('EventsController event cache write error: $error');
      }
    }();
    _cacheWriteQueue = write;
    await write;
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

  Future<bool> updateEvent(Event event) async {
    try {
      await _repository.updateEvent(event);
    } catch (error) {
      debugPrint('EventsController.updateEvent error: $error');
      _recordError(error, fallbackMessage: 'Unable to update event.');
      notifyListeners();
      return false;
    }

    return loadEvents();
  }

  Future<bool> cancelEvent(String eventId) async {
    try {
      await _repository.cancelEvent(eventId);
    } catch (error) {
      debugPrint('EventsController.cancelEvent error: $error');
      _recordError(error, fallbackMessage: 'Unable to cancel event.');
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
