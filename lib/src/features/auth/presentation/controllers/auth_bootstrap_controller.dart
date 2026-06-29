import 'package:flutter/foundation.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_gateway.dart';
import '../../domain/repositories/profile_repository.dart';

enum AuthBootstrapState { initializing, ready, error }

class AuthBootstrapController extends ChangeNotifier {
  AuthBootstrapController({
    required AuthGateway authGateway,
    required ProfileRepository profileRepository,
  }) : _authGateway = authGateway,
       _profileRepository = profileRepository;

  final AuthGateway _authGateway;
  final ProfileRepository _profileRepository;

  AuthBootstrapState _state = AuthBootstrapState.initializing;
  String? _userId;
  UserProfile? _profile;
  Object? _error;

  AuthBootstrapState get state => _state;
  String? get userId => _userId;
  UserProfile? get profile => _profile;
  Object? get error => _error;

  Future<void> bootstrap() async {
    _state = AuthBootstrapState.initializing;
    _userId = null;
    _profile = null;
    _error = null;
    notifyListeners();

    try {
      final existingUserId = _authGateway.currentUserId;
      final authenticatedUserId =
          existingUserId ?? await _authGateway.signInAnonymously();

      if (authenticatedUserId.isEmpty) {
        throw StateError('Authentication did not provide a user ID.');
      }

      await _profileRepository.upsert(authenticatedUserId);
      final profile = await _profileRepository.load(authenticatedUserId);

      if (profile.id != authenticatedUserId) {
        throw StateError(
          'Loaded profile does not match the authenticated user.',
        );
      }

      _userId = authenticatedUserId;
      _profile = profile;
      _state = AuthBootstrapState.ready;
    } catch (error) {
      debugPrint('AuthBootstrapController.bootstrap error: $error');
      _error = error;
      _state = AuthBootstrapState.error;
    }

    notifyListeners();
  }
}
