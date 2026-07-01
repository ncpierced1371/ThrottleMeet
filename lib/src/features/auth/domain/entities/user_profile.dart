class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final createdAt = map['created_at'];
    final updatedAt = map['updated_at'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Profile id is missing or invalid.');
    }
    if (createdAt is! String) {
      throw const FormatException('Profile created_at is missing or invalid.');
    }
    if (updatedAt is! String) {
      throw const FormatException('Profile updated_at is missing or invalid.');
    }

    return UserProfile(
      id: id,
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  final String id;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
}
