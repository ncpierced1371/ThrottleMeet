import 'auth_session_provider.dart';

abstract class AuthGateway implements AuthSessionProvider {
  Future<String> signInAnonymously();
}
