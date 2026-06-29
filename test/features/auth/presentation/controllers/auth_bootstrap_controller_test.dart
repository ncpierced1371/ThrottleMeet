import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/entities/user_profile.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/repositories/auth_gateway.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/repositories/profile_repository.dart';
import 'package:throttlemeet_v2/src/features/auth/presentation/controllers/auth_bootstrap_controller.dart';

void main() {
  group('AuthBootstrapController', () {
    test('reuses an existing session and loads its profile', () async {
      final authGateway = _FakeAuthGateway(currentUserId: 'user-a');
      final profileRepository = _FakeProfileRepository();
      final controller = AuthBootstrapController(
        authGateway: authGateway,
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();

      expect(controller.state, AuthBootstrapState.ready);
      expect(controller.userId, 'user-a');
      expect(controller.profile?.id, 'user-a');
      expect(authGateway.anonymousSignInCount, 0);
      expect(profileRepository.upsertedUserIds, ['user-a']);
      expect(profileRepository.loadedUserIds, ['user-a']);
    });

    test('signs in anonymously when no session exists', () async {
      final authGateway = _FakeAuthGateway(anonymousUserId: 'anonymous-a');
      final profileRepository = _FakeProfileRepository();
      final controller = AuthBootstrapController(
        authGateway: authGateway,
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();

      expect(controller.state, AuthBootstrapState.ready);
      expect(controller.userId, 'anonymous-a');
      expect(authGateway.anonymousSignInCount, 1);
      expect(profileRepository.upsertedUserIds, ['anonymous-a']);
      expect(profileRepository.loadedUserIds, ['anonymous-a']);
    });

    test('enters error state when anonymous sign-in fails', () async {
      final authError = StateError('auth unavailable');
      final authGateway = _FakeAuthGateway(signInError: authError);
      final profileRepository = _FakeProfileRepository();
      final controller = AuthBootstrapController(
        authGateway: authGateway,
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();

      expect(controller.state, AuthBootstrapState.error);
      expect(controller.error, same(authError));
      expect(controller.userId, isNull);
      expect(profileRepository.upsertedUserIds, isEmpty);
      expect(profileRepository.loadedUserIds, isEmpty);
    });

    test('enters error state when profile upsert fails', () async {
      final profileError = StateError('profile upsert failed');
      final profileRepository = _FakeProfileRepository(
        upsertError: profileError,
      );
      final controller = AuthBootstrapController(
        authGateway: _FakeAuthGateway(currentUserId: 'user-a'),
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();

      expect(controller.state, AuthBootstrapState.error);
      expect(controller.error, same(profileError));
      expect(profileRepository.upsertedUserIds, ['user-a']);
      expect(profileRepository.loadedUserIds, isEmpty);
    });

    test('enters error state when profile load fails', () async {
      final profileError = StateError('profile load failed');
      final profileRepository = _FakeProfileRepository(loadError: profileError);
      final controller = AuthBootstrapController(
        authGateway: _FakeAuthGateway(currentUserId: 'user-a'),
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();

      expect(controller.state, AuthBootstrapState.error);
      expect(controller.error, same(profileError));
      expect(profileRepository.upsertedUserIds, ['user-a']);
      expect(profileRepository.loadedUserIds, ['user-a']);
    });
  });
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({
    this.currentUserId,
    this.anonymousUserId = 'anonymous-user',
    this.signInError,
  });

  @override
  final String? currentUserId;
  final String anonymousUserId;
  final Object? signInError;
  int anonymousSignInCount = 0;

  @override
  Future<String> signInAnonymously() async {
    anonymousSignInCount += 1;
    final error = signInError;
    if (error != null) {
      throw error;
    }
    return anonymousUserId;
  }
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.upsertError, this.loadError});

  final Object? upsertError;
  final Object? loadError;
  final List<String> upsertedUserIds = [];
  final List<String> loadedUserIds = [];

  @override
  Future<void> upsert(String userId) async {
    upsertedUserIds.add(userId);
    final error = upsertError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<UserProfile> load(String userId) async {
    loadedUserIds.add(userId);
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return UserProfile(
      id: userId,
      displayName: null,
      createdAt: DateTime.utc(2026, 6, 28),
      updatedAt: DateTime.utc(2026, 6, 28),
    );
  }
}
