import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();
typedef ParticipantIdGenerator = String Function();

class ParticipantIdStore {
  ParticipantIdStore({
    SharedPreferencesLoader? loadPreferences,
    ParticipantIdGenerator? generateParticipantId,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance,
       _generateParticipantId = generateParticipantId ?? const Uuid().v4;

  static const storageKey = 'anonymous_participant_id';

  final SharedPreferencesLoader _loadPreferences;
  final ParticipantIdGenerator _generateParticipantId;

  String? _cachedParticipantId;
  Future<String>? _pendingLoad;

  Future<String> getOrCreateParticipantId() async {
    final cachedParticipantId = _cachedParticipantId;
    if (cachedParticipantId != null) {
      return cachedParticipantId;
    }

    final pendingLoad = _pendingLoad;
    if (pendingLoad != null) {
      return pendingLoad;
    }

    final load = _loadOrCreateParticipantId();
    _pendingLoad = load;

    try {
      return await load;
    } finally {
      if (identical(_pendingLoad, load)) {
        _pendingLoad = null;
      }
    }
  }

  Future<String> _loadOrCreateParticipantId() async {
    final preferences = await _loadPreferences();
    final existingParticipantId = preferences.getString(storageKey);

    if (existingParticipantId != null && existingParticipantId.isNotEmpty) {
      _cachedParticipantId = existingParticipantId;
      return existingParticipantId;
    }

    final participantId = _generateParticipantId();
    final didPersist = await preferences.setString(storageKey, participantId);

    if (!didPersist) {
      throw StateError('Unable to persist anonymous participant ID.');
    }

    _cachedParticipantId = participantId;
    return participantId;
  }
}
