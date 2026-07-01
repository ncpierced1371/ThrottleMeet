import '../entities/user_profile.dart';

abstract class ProfileRepository {
  Future<void> upsert(String userId);

  Future<UserProfile> load(String userId);

  Future<UserProfile> update({
    required String userId,
    required String displayName,
    String? avatarUrl,
  });
}
