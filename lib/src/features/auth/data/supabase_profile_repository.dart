import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/user_profile.dart';
import '../domain/repositories/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({
    SupabaseClient? client,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? Supabase.instance.client,
       _requestTimeout = requestTimeout;

  final SupabaseClient _client;
  final Duration _requestTimeout;

  @override
  Future<void> upsert(String userId) async {
    await _client
        .from('profiles')
        .upsert({'id': userId}, onConflict: 'id', ignoreDuplicates: true)
        .timeout(_requestTimeout);
  }

  @override
  Future<UserProfile> load(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single()
        .timeout(_requestTimeout);
    return UserProfile.fromMap(data);
  }

  @override
  Future<UserProfile> update({
    required String userId,
    required String displayName,
    String? avatarUrl,
  }) async {
    final data = await _client
        .from('profiles')
        .upsert({
          'id': userId,
          'display_name': displayName,
          'avatar_url': avatarUrl,
        }, onConflict: 'id')
        .select()
        .single()
        .timeout(_requestTimeout);
    return UserProfile.fromMap(data);
  }
}
