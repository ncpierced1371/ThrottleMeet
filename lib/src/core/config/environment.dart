class Environment {
  const Environment._({required this.supabaseUrl, required this.supabaseKey});

  final String supabaseUrl;
  final String supabaseKey;

  factory Environment.load({
    String supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
    String supabaseKey = const String.fromEnvironment('SUPABASE_KEY'),
  }) {
    return Environment._(
      supabaseUrl: _requireValue('SUPABASE_URL', supabaseUrl),
      supabaseKey: _requireValue('SUPABASE_KEY', supabaseKey),
    );
  }

  static String _requireValue(String name, String value) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      throw StateError(
        'Missing required $name. '
        'Supply it with --dart-define=$name=<value>.',
      );
    }
    return normalizedValue;
  }
}
