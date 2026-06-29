import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/core/config/supabase_config.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabaseConfig = SupabaseConfig.fromEnvironment();
  await Supabase.initialize(
    url: supabaseConfig.url,
    publishableKey: supabaseConfig.publishableKey,
  );
  runApp(const ThrottleMeetApp());
}
