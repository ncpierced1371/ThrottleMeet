import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/repositories/auth_gateway.dart';

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway({
    SupabaseClient? client,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? Supabase.instance.client,
       _requestTimeout = requestTimeout;

  final SupabaseClient _client;
  final Duration _requestTimeout;

  @override
  String? get currentUserId => _client.auth.currentSession?.user.id;

  @override
  Future<String> signInAnonymously() async {
    final response = await _client.auth.signInAnonymously().timeout(
      _requestTimeout,
    );
    final userId = response.session?.user.id ?? response.user?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError(
        'Anonymous sign-in did not return an authenticated user.',
      );
    }
    return userId;
  }
}
