import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_rsvp_attendee.dart';
import '../../domain/entities/rsvp_status.dart';
import '../../domain/repositories/events_repository.dart';

enum EventListFilter { all, upcoming, mine }

enum OwnerRsvpListStatus { idle, loading, data, error }

class EventsController extends ChangeNotifier {
  EventsController({
    required EventsRepository repository,
    DateTime Function()? now,
  }) : _repository = repository,
       _now = now ?? DateTime.now;

  final EventsRepository _repository;
  final DateTime Function() _now;

  List<Event> _events = [];
  bool _isLoading = false;
  String? _errorMessage;
  AppErrorType? _errorType;
  bool _isShowingCachedEvents = false;
  DateTime? _cachedAt;
  int _cachedEventCount = 0;
  DateTime? _latestSuccessfulEventRefreshAt;
  DateTime? _latestCacheWriteAt;
  int _loadGeneration = 0;
  Future<void> _cacheWriteQueue = Future.value();
  EventListFilter _selectedFilter = EventListFilter.all;
  OwnerRsvpListStatus _ownerRsvpListStatus = OwnerRsvpListStatus.idle;
  List<EventRsvpAttendee> _ownerRsvpAttendees = const [];
  String? _ownerRsvpListErrorMessage;
  String? _ownerRsvpListEventId;
  int _ownerRsvpListGeneration = 0;

  List<Event> get events => _events;
  EventListFilter get selectedFilter => _selectedFilter;
  List<Event> get visibleEvents {
    return switch (_selectedFilter) {
      EventListFilter.all => _events,
      EventListFilter.upcoming =>
        _events
            .where((event) => event.startTime.isAfter(_now()))
            .toList(growable: false),
      EventListFilter.mine => _events.where(_isMine).toList(growable: false),
    };
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AppErrorType? get errorType => _errorType;
  bool get isShowingCachedEvents => _isShowingCachedEvents;
  DateTime? get cachedAt => _cachedAt;
  int get cachedEventCount => _cachedEventCount;
  DateTime? get latestSuccessfulEventRefreshAt =>
      _latestSuccessfulEventRefreshAt;
  DateTime? get latestCacheWriteAt => _latestCacheWriteAt;
  OwnerRsvpListStatus get ownerRsvpListStatus => _ownerRsvpListStatus;
  List<EventRsvpAttendee> get ownerRsvpAttendees => _ownerRsvpAttendees;
  String? get ownerRsvpListErrorMessage => _ownerRsvpListErrorMessage;
  String? get ownerRsvpListEventId => _ownerRsvpListEventId;

  void selectFilter(EventListFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }
    _selectedFilter = filter;
    notifyListeners();
  }

  static bool _isMine(Event event) {
    return event.isOwnedByViewer ||
        event.viewerRsvpStatus == RsvpStatus.going ||
        event.viewerRsvpStatus == RsvpStatus.interested;
  }

  Future<bool> loadEvents() async {
    final generation = ++_loadGeneration;
    _isLoading = true;
    _errorMessage = null;
    _errorType = null;
    AppLogger.info('event.refresh.started', fields: {'generation': generation});
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
            _cachedEventCount = snapshot.events.length;
            _latestCacheWriteAt = snapshot.cachedAt;
            AppLogger.info(
              'event.cache.loaded',
              fields: {'event_count': snapshot.events.length},
            );
            notifyListeners();
          }
        } catch (error) {
          if (!_isCurrentLoad(generation)) {
            return false;
          }
          AppLogger.warning('event.cache.read_failed', error: error);
        }
      }

      final events = await _repository.getEvents();
      if (!_isCurrentLoad(generation)) {
        return false;
      }

      _events = events;
      _isShowingCachedEvents = false;
      _cachedAt = null;
      _latestSuccessfulEventRefreshAt = _now().toUtc();
      AppLogger.info(
        'event.refresh.succeeded',
        fields: {'event_count': events.length, 'generation': generation},
      );
      notifyListeners();

      await _queueCacheWrite(events);
      return _isCurrentLoad(generation);
    } catch (error, stackTrace) {
      if (!_isCurrentLoad(generation)) {
        return false;
      }
      AppLogger.error(
        'event.refresh.failed',
        fields: {'generation': generation},
        error: error,
        stackTrace: stackTrace,
      );
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
        _cachedEventCount = events.length;
        _latestCacheWriteAt = _now().toUtc();
        AppLogger.info(
          'event.cache.write_succeeded',
          fields: {'event_count': events.length},
        );
        notifyListeners();
      } catch (error) {
        AppLogger.warning('event.cache.write_failed', error: error);
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

  Future<bool> loadEventRsvpsForOwner(String eventId) async {
    final generation = ++_ownerRsvpListGeneration;
    final isNewEvent = _ownerRsvpListEventId != eventId;
    _ownerRsvpListEventId = eventId;
    if (isNewEvent) {
      _ownerRsvpAttendees = const [];
    }
    _ownerRsvpListStatus = OwnerRsvpListStatus.loading;
    _ownerRsvpListErrorMessage = null;
    AppLogger.info(
      'event.owner_rsvp_list.started',
      fields: {'event_id': eventId, 'generation': generation},
    );
    notifyListeners();

    try {
      final attendees = await _repository.getEventRsvpsForOwner(eventId);
      if (!_isCurrentOwnerRsvpList(generation, eventId)) {
        return false;
      }
      _ownerRsvpAttendees = List.unmodifiable(attendees);
      _ownerRsvpListStatus = OwnerRsvpListStatus.data;
      AppLogger.info(
        'event.owner_rsvp_list.succeeded',
        fields: {'event_id': eventId, 'attendee_count': attendees.length},
      );
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      if (!_isCurrentOwnerRsvpList(generation, eventId)) {
        return false;
      }
      _ownerRsvpListStatus = OwnerRsvpListStatus.error;
      _ownerRsvpListErrorMessage = _messageForError(
        error,
        fallbackMessage: 'Unable to load organizer attendance.',
      );
      AppLogger.error(
        'event.owner_rsvp_list.failed',
        fields: {'event_id': eventId},
        error: error,
        stackTrace: stackTrace,
      );
      notifyListeners();
      return false;
    }
  }

  bool _isCurrentOwnerRsvpList(int generation, String eventId) {
    return generation == _ownerRsvpListGeneration &&
        _ownerRsvpListEventId == eventId;
  }

  Future<bool> createNewEvent(Event event) async {
    AppLogger.info('event.create.started', fields: {'event_id': event.id});
    try {
      await _repository.createEvent(event);
      AppLogger.info(
        'event.create.write_succeeded',
        fields: {'event_id': event.id},
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'event.create.failed',
        fields: {'event_id': event.id},
        error: error,
        stackTrace: stackTrace,
      );
      _recordError(error, fallbackMessage: 'Unable to create event.');
      notifyListeners();
      return false;
    }

    return loadEvents();
  }

  Future<bool> updateEvent(Event event) async {
    AppLogger.info('event.edit.started', fields: {'event_id': event.id});
    try {
      await _repository.updateEvent(event);
      AppLogger.info(
        'event.edit.write_succeeded',
        fields: {'event_id': event.id},
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'event.edit.failed',
        fields: {'event_id': event.id},
        error: error,
        stackTrace: stackTrace,
      );
      _recordError(error, fallbackMessage: 'Unable to update event.');
      notifyListeners();
      return false;
    }

    return loadEvents();
  }

  Future<bool> cancelEvent(String eventId) async {
    AppLogger.info('event.cancel.started', fields: {'event_id': eventId});
    try {
      await _repository.cancelEvent(eventId);
      AppLogger.info(
        'event.cancel.write_succeeded',
        fields: {'event_id': eventId},
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'event.cancel.failed',
        fields: {'event_id': eventId},
        error: error,
        stackTrace: stackTrace,
      );
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
    AppLogger.info(
      'event.rsvp_update.started',
      fields: {'event_id': eventId, 'status': status.name},
    );
    try {
      await _repository.updateRsvp(eventId: eventId, status: status);
      AppLogger.info(
        'event.rsvp_update.write_succeeded',
        fields: {'event_id': eventId, 'status': status.name},
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'event.rsvp_update.failed',
        fields: {'event_id': eventId, 'status': status.name},
        error: error,
        stackTrace: stackTrace,
      );
      _recordError(error, fallbackMessage: 'Unable to update RSVP.');
      notifyListeners();
      return false;
    }

    return loadEvents();
  }

  void _recordError(Object error, {required String fallbackMessage}) {
    final appException = _appExceptionFor(error);
    _errorType = appException.type;
    _errorMessage = _messageForAppException(
      appException,
      fallbackMessage: fallbackMessage,
    );
  }

  String _messageForError(Object error, {required String fallbackMessage}) {
    return _messageForAppException(
      _appExceptionFor(error),
      fallbackMessage: fallbackMessage,
    );
  }

  static AppException _appExceptionFor(Object error) {
    final appException = error is AppException
        ? error
        : AppException(type: AppErrorType.unknown, cause: error);
    return appException;
  }

  static String _messageForAppException(
    AppException appException, {
    required String fallbackMessage,
  }) {
    return switch (appException.type) {
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
