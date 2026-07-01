import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/features/auth/domain/entities/user_profile.dart';

void main() {
  test('maps all persisted profile fields', () {
    final profile = UserProfile.fromMap({
      'id': 'user-a',
      'display_name': 'Avery',
      'avatar_url': 'https://example.com/avery.jpg',
      'created_at': '2026-06-30T12:00:00Z',
      'updated_at': '2026-07-01T12:00:00Z',
    });

    expect(profile.id, 'user-a');
    expect(profile.displayName, 'Avery');
    expect(profile.avatarUrl, 'https://example.com/avery.jpg');
    expect(profile.createdAt, DateTime.utc(2026, 6, 30, 12));
    expect(profile.updatedAt, DateTime.utc(2026, 7, 1, 12));
  });

  test('allows a profile without an avatar URL', () {
    final profile = UserProfile.fromMap({
      'id': 'user-a',
      'display_name': null,
      'created_at': '2026-06-30T12:00:00Z',
      'updated_at': '2026-07-01T12:00:00Z',
    });

    expect(profile.avatarUrl, isNull);
  });
}
