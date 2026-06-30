import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/entities/user_profile.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/repositories/auth_gateway.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/repositories/profile_repository.dart';
import 'package:throttlemeet_v2/src/features/auth/presentation/controllers/auth_bootstrap_controller.dart';

void main() {
  group('AuthBootstrapController', () {
    test('existing session is ready before profile sync completes', () async {
      final pendingUpsert = Completer<void>();
      final authGateway = _FakeAuthGateway(currentUserId: 'user-a');
      final profileRepository = _FakeProfileRepository()
        ..pendingUpserts.add(pendingUpsert);
      final controller = AuthBootstrapController(
        authGateway: authGateway,
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();

      expect(controller.state, AuthBootstrapState.ready);
      expect(controller.userId, 'user-a');
      expect(controller.profileSyncStatus, ProfileSyncStatus.syncing);
      expect(authGateway.anonymousSignInCount, 0);

      pendingUpsert.complete();
      await _waitForProfileStatus(controller, ProfileSyncStatus.ready);

      expect(controller.profile?.id, 'user-a');
      expect(profileRepository.upsertedUserIds, ['user-a']);
      expect(profileRepository.loadedUserIds, ['user-a']);
    });

    test('anonymous sign-in remains required when session is absent', () async {
      final authGateway = _FakeAuthGateway(anonymousUserId: 'anonymous-a');
      final profileRepository = _FakeProfileRepository();
      final controller = AuthBootstrapController(
        authGateway: authGateway,
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();
      await _waitForProfileStatus(controller, ProfileSyncStatus.ready);

      expect(controller.state, AuthBootstrapState.ready);
      expect(controller.userId, 'anonymous-a');
      expect(authGateway.anonymousSignInCount, 1);
      expect(controller.profile?.id, 'anonymous-a');
    });

    test('auth failure remains blocking and does not sync profile', () async {
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
      expect(controller.authError, same(authError));
      expect(controller.profileSyncStatus, ProfileSyncStatus.idle);
      expect(controller.userId, isNull);
      expect(profileRepository.upsertedUserIds, isEmpty);
      expect(profileRepository.loadedUserIds, isEmpty);
    });

    test('existing session stays ready when profile upsert fails', () async {
      final profileError = StateError('profile upsert failed');
      final profileRepository = _FakeProfileRepository()
        ..upsertError = profileError;
      final controller = AuthBootstrapController(
        authGateway: _FakeAuthGateway(currentUserId: 'user-a'),
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();
      await _waitForProfileStatus(controller, ProfileSyncStatus.error);

      expect(controller.state, AuthBootstrapState.ready);
      expect(controller.userId, 'user-a');
      expect(controller.authError, isNull);
      expect(controller.profileError, same(profileError));
      expect(profileRepository.loadedUserIds, isEmpty);
    });

    test('anonymous user stays ready when profile upsert fails', () async {
      final profileError = StateError('profile upsert failed');
      final authGateway = _FakeAuthGateway(anonymousUserId: 'anonymous-a');
      final profileRepository = _FakeProfileRepository()
        ..upsertError = profileError;
      final controller = AuthBootstrapController(
        authGateway: authGateway,
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();
      await _waitForProfileStatus(controller, ProfileSyncStatus.error);

      expect(controller.state, AuthBootstrapState.ready);
      expect(controller.userId, 'anonymous-a');
      expect(controller.profileError, same(profileError));
      expect(authGateway.anonymousSignInCount, 1);
    });

    test('profile load failure is separate from auth state', () async {
      final profileError = StateError('profile load failed');
      final profileRepository = _FakeProfileRepository()
        ..loadError = profileError;
      final controller = AuthBootstrapController(
        authGateway: _FakeAuthGateway(currentUserId: 'user-a'),
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();
      await _waitForProfileStatus(controller, ProfileSyncStatus.error);

      expect(controller.state, AuthBootstrapState.ready);
      expect(controller.userId, 'user-a');
      expect(controller.authError, isNull);
      expect(controller.profileError, same(profileError));
      expect(profileRepository.loadedUserIds, ['user-a']);
    });

    test('profile retry clears error without another auth call', () async {
      final authGateway = _FakeAuthGateway(anonymousUserId: 'anonymous-a');
      final profileRepository = _FakeProfileRepository()
        ..upsertError = StateError('offline');
      final controller = AuthBootstrapController(
        authGateway: authGateway,
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();
      await _waitForProfileStatus(controller, ProfileSyncStatus.error);
      profileRepository.upsertError = null;

      await controller.retryProfileSync();

      expect(controller.state, AuthBootstrapState.ready);
      expect(controller.profileSyncStatus, ProfileSyncStatus.ready);
      expect(controller.profileError, isNull);
      expect(controller.profile?.id, 'anonymous-a');
      expect(authGateway.anonymousSignInCount, 1);
    });

    test('stale profile failure cannot overwrite newer success', () async {
      final olderUpsert = Completer<void>();
      final profileRepository = _FakeProfileRepository()
        ..pendingUpserts.add(olderUpsert);
      final controller = AuthBootstrapController(
        authGateway: _FakeAuthGateway(currentUserId: 'user-a'),
        profileRepository: profileRepository,
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();
      expect(controller.profileSyncStatus, ProfileSyncStatus.syncing);

      await controller.retryProfileSync();
      expect(controller.profileSyncStatus, ProfileSyncStatus.ready);

      olderUpsert.completeError(StateError('older failure'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.profileSyncStatus, ProfileSyncStatus.ready);
      expect(controller.profileError, isNull);
      expect(controller.profile?.id, 'user-a');
    });
  });
}

Future<void> _waitForProfileStatus(
  AuthBootstrapController controller,
  ProfileSyncStatus status,
) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    if (controller.profileSyncStatus == status) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail(
    'Profile status did not become $status. '
    'Current status: ${controller.profileSyncStatus}',
  );
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({
    this.currentUserId,
    this.anonymousUserId = 'anonymous-user',
    this.signInError,
  });

  @override
  String? currentUserId;
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
  Object? upsertError;
  Object? loadError;
  final List<Completer<void>> pendingUpserts = [];
  final List<String> upsertedUserIds = [];
  final List<String> loadedUserIds = [];

  @override
  Future<void> upsert(String userId) async {
    upsertedUserIds.add(userId);
    if (pendingUpserts.isNotEmpty) {
      await pendingUpserts.removeAt(0).future;
    }
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
