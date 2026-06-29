import 'environment.dart';

class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  factory SupabaseConfig.fromEnvironment({Environment? environment}) {
    final values = environment ?? Environment.load();
    return SupabaseConfig(
      url: values.supabaseUrl,
      publishableKey: values.supabaseKey,
    );
  }

  final String url;
  final String publishableKey;
}
