import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_gateway.dart';
import '../../domain/repositories/profile_repository.dart';

enum AuthBootstrapState { initializing, ready, error }

enum ProfileSyncStatus { idle, syncing, ready, error }

class AuthBootstrapController extends ChangeNotifier {
  AuthBootstrapController({
    required AuthGateway authGateway,
    required ProfileRepository profileRepository,
  }) : _authGateway = authGateway,
       _profileRepository = profileRepository;

  final AuthGateway _authGateway;
  final ProfileRepository _profileRepository;

  AuthBootstrapState _state = AuthBootstrapState.initializing;
  ProfileSyncStatus _profileSyncStatus = ProfileSyncStatus.idle;
  String? _userId;
  UserProfile? _profile;
  Object? _authError;
  Object? _profileError;
  int _bootstrapGeneration = 0;
  int _profileSyncGeneration = 0;

  AuthBootstrapState get state => _state;
  AuthBootstrapState get authState => _state;
  ProfileSyncStatus get profileSyncStatus => _profileSyncStatus;
  String? get userId => _userId;
  UserProfile? get profile => _profile;
  Object? get authError => _authError;
  Object? get profileError => _profileError;

  // Retained as an auth-error alias for existing callers.
  Object? get error => _authError;

  Future<void> bootstrap() async {
    final generation = ++_bootstrapGeneration;
    _profileSyncGeneration += 1;
    _state = AuthBootstrapState.initializing;
    _profileSyncStatus = ProfileSyncStatus.idle;
    _userId = null;
    _profile = null;
    _authError = null;
    _profileError = null;
    notifyListeners();

    try {
      final existingUserId = _authGateway.currentUserId;
      final authenticatedUserId =
          existingUserId ?? await _authGateway.signInAnonymously();

      if (authenticatedUserId.isEmpty) {
        throw StateError('Authentication did not provide a user ID.');
      }

      if (generation != _bootstrapGeneration) {
        return;
      }

      _userId = authenticatedUserId;
      _state = AuthBootstrapState.ready;
      notifyListeners();

      unawaited(syncProfile());
    } catch (error) {
      if (generation != _bootstrapGeneration) {
        return;
      }
      debugPrint('AuthBootstrapController.bootstrap error: $error');
      _authError = error;
      _state = AuthBootstrapState.error;
      notifyListeners();
    }
  }

  Future<void> retryProfileSync() => syncProfile();

  Future<void> syncProfile() async {
    final authenticatedUserId = _userId;
    if (_state != AuthBootstrapState.ready || authenticatedUserId == null) {
      return;
    }

    final generation = ++_profileSyncGeneration;
    _profileSyncStatus = ProfileSyncStatus.syncing;
    _profileError = null;
    notifyListeners();

    try {
      await _profileRepository.upsert(authenticatedUserId);
      final profile = await _profileRepository.load(authenticatedUserId);

      if (profile.id != authenticatedUserId) {
        throw StateError(
          'Loaded profile does not match the authenticated user.',
        );
      }

      if (!_isCurrentProfileSync(generation, authenticatedUserId)) {
        return;
      }

      _profile = profile;
      _profileSyncStatus = ProfileSyncStatus.ready;
      notifyListeners();
    } catch (error) {
      if (!_isCurrentProfileSync(generation, authenticatedUserId)) {
        return;
      }
      debugPrint('AuthBootstrapController.syncProfile error: $error');
      _profileError = error;
      _profileSyncStatus = ProfileSyncStatus.error;
      notifyListeners();
    }
  }

  bool _isCurrentProfileSync(int generation, String userId) {
    return generation == _profileSyncGeneration &&
        _state == AuthBootstrapState.ready &&
        _userId == userId;
  }
}
