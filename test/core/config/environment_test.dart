import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/core/config/environment.dart';
import 'package:throttlemeet_v2/src/core/config/supabase_config.dart';

void main() {
  group('Environment', () {
    test('throws a clear error when SUPABASE_URL is missing', () {
      expect(
        () => Environment.load(
          supabaseUrl: '',
          supabaseKey: 'test-publishable-key',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('SUPABASE_URL'),
          ),
        ),
      );
    });

    test('throws a clear error when SUPABASE_KEY is missing', () {
      expect(
        () => Environment.load(
          supabaseUrl: 'https://example.supabase.co',
          supabaseKey: '  ',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('SUPABASE_KEY'),
          ),
        ),
      );
    });

    test('loads supplied values and configures Supabase', () {
      final environment = Environment.load(
        supabaseUrl: ' https://example.supabase.co ',
        supabaseKey: ' test-publishable-key ',
      );

      final config = SupabaseConfig.fromEnvironment(environment: environment);

      expect(environment.supabaseUrl, 'https://example.supabase.co');
      expect(environment.supabaseKey, 'test-publishable-key');
      expect(config.url, environment.supabaseUrl);
      expect(config.publishableKey, environment.supabaseKey);
    });
  });
}
