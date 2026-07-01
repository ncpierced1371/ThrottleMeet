import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/event_snapshot.dart';
import '../models/event_record.dart';

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();

abstract class EventSnapshotCache {
  Future<EventSnapshot?> read(String userId);

  Future<void> write(String userId, EventSnapshot snapshot);
}

class SharedPreferencesEventSnapshotCache implements EventSnapshotCache {
  SharedPreferencesEventSnapshotCache({
    SharedPreferencesLoader? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const _keyPrefix = 'authenticated_event_snapshot_v1';

  final SharedPreferencesLoader _loadPreferences;

  @override
  Future<EventSnapshot?> read(String userId) async {
    final preferences = await _loadPreferences();
    final key = _keyFor(userId);
    final encodedSnapshot = preferences.getString(key);
    if (encodedSnapshot == null) {
      return null;
    }

    try {
      final decodedSnapshot = jsonDecode(encodedSnapshot);
      if (decodedSnapshot is! Map<String, dynamic>) {
        throw const FormatException('Event snapshot must be a JSON object.');
      }

      final cachedAtValue = decodedSnapshot['cached_at'];
      final eventValues = decodedSnapshot['events'];
      if (cachedAtValue is! String || eventValues is! List) {
        throw const FormatException('Event snapshot fields are invalid.');
      }

      final cachedAt = DateTime.tryParse(cachedAtValue);
      if (cachedAt == null) {
        throw const FormatException('Event snapshot timestamp is invalid.');
      }

      final events = eventValues.map((value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Cached event must be a JSON object.');
        }
        return EventRecord.fromMap(value).toEntity();
      }).toList();

      return EventSnapshot(events: events, cachedAt: cachedAt.toUtc());
    } catch (error) {
      AppLogger.warning('event.cache.invalid_snapshot', error: error);
      await preferences.remove(key);
      return null;
    }
  }

  @override
  Future<void> write(String userId, EventSnapshot snapshot) async {
    final preferences = await _loadPreferences();
    final encodedSnapshot = jsonEncode({
      'cached_at': snapshot.cachedAt.toUtc().toIso8601String(),
      'events': snapshot.events
          .map((event) => EventRecord.fromEntity(event).toSnapshotMap())
          .toList(),
    });
    final didPersist = await preferences.setString(
      _keyFor(userId),
      encodedSnapshot,
    );
    if (!didPersist) {
      throw StateError('Unable to persist authenticated event snapshot.');
    }
  }

  String _keyFor(String userId) => '$_keyPrefix:$userId';
}
