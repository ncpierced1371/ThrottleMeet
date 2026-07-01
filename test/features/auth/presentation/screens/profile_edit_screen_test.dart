import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/core/theme/app_theme.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/entities/user_profile.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/repositories/auth_gateway.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/repositories/profile_repository.dart';
import 'package:throttlemeet_v2/src/features/auth/presentation/controllers/auth_bootstrap_controller.dart';
import 'package:throttlemeet_v2/src/features/auth/presentation/screens/profile_edit_screen.dart';

void main() {
  testWidgets('displays the current profile values', (tester) async {
    final fixture = await _pumpProfileScreen(tester);

    expect(find.text('Avery Driver'), findsOneWidget);
    expect(find.text('https://example.com/avery.jpg'), findsOneWidget);
    expect(find.text(fixture.controller.userId!), findsNothing);
  });

  testWidgets('saving a valid display name updates the repository', (
    tester,
  ) async {
    final fixture = await _pumpProfileScreen(tester);

    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      '  New Driver  ',
    );
    await tester.enterText(
      find.byKey(const Key('profile-avatar-url-field')),
      '  https://example.com/new.jpg  ',
    );
    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pumpAndSettle();

    expect(fixture.repository.updateCount, 1);
    expect(fixture.repository.savedDisplayName, 'New Driver');
    expect(fixture.repository.savedAvatarUrl, 'https://example.com/new.jpg');
    expect(fixture.controller.profile?.displayName, 'New Driver');
    expect(find.text('Profile saved.'), findsOneWidget);
  });

  testWidgets('rejects an empty display name', (tester) async {
    final fixture = await _pumpProfileScreen(tester);

    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      '   ',
    );
    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pump();

    expect(find.text('Enter a display name.'), findsOneWidget);
    expect(fixture.repository.updateCount, 0);
  });

  testWidgets('rejects an overly long display name', (tester) async {
    final fixture = await _pumpProfileScreen(tester);

    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      List.filled(41, 'A').join(),
    );
    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pump();

    expect(
      find.text('Display name must be 40 characters or fewer.'),
      findsOneWidget,
    );
    expect(fixture.repository.updateCount, 0);
  });

  testWidgets('failed save shows an error and preserves the form', (
    tester,
  ) async {
    final fixture = await _pumpProfileScreen(tester);
    fixture.repository.updateError = StateError('offline');

    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      'Preserved Driver',
    );
    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pumpAndSettle();

    expect(find.text('Preserved Driver'), findsOneWidget);
    expect(
      find.text('Unable to save profile. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(fixture.controller.state, AuthBootstrapState.ready);
    expect(fixture.controller.profileSyncStatus, ProfileSyncStatus.error);
  });
}

Future<_ProfileFixture> _pumpProfileScreen(WidgetTester tester) async {
  final repository = _FakeProfileRepository();
  final controller = AuthBootstrapController(
    authGateway: _FakeAuthGateway(),
    profileRepository: repository,
  );
  addTearDown(controller.dispose);
  await controller.bootstrap();
  await controller.retryProfileSync();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: ProfileEditScreen(authController: controller),
    ),
  );
  return _ProfileFixture(controller, repository);
}

class _ProfileFixture {
  const _ProfileFixture(this.controller, this.repository);

  final AuthBootstrapController controller;
  final _FakeProfileRepository repository;
}

class _FakeAuthGateway implements AuthGateway {
  @override
  String? get currentUserId => 'profile-user';

  @override
  Future<String> signInAnonymously() async => 'profile-user';
}

class _FakeProfileRepository implements ProfileRepository {
  UserProfile profile = UserProfile(
    id: 'profile-user',
    displayName: 'Avery Driver',
    avatarUrl: 'https://example.com/avery.jpg',
    createdAt: DateTime.utc(2026, 6, 30),
    updatedAt: DateTime.utc(2026, 6, 30),
  );
  Object? updateError;
  int updateCount = 0;
  String? savedDisplayName;
  String? savedAvatarUrl;

  @override
  Future<void> upsert(String userId) async {}

  @override
  Future<UserProfile> load(String userId) async => profile;

  @override
  Future<UserProfile> update({
    required String userId,
    required String displayName,
    String? avatarUrl,
  }) async {
    updateCount += 1;
    savedDisplayName = displayName;
    savedAvatarUrl = avatarUrl;
    final error = updateError;
    if (error != null) {
      throw error;
    }
    profile = UserProfile(
      id: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      createdAt: profile.createdAt,
      updatedAt: DateTime.utc(2026, 7, 1),
    );
    return profile;
  }
}
