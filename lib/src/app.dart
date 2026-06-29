import 'package:flutter/material.dart';

import 'core/identity/participant_id_store.dart';
import 'core/theme/app_theme.dart';
import 'features/events/data/cache/event_snapshot_cache.dart';
import 'features/events/data/repositories/supabase_events_repository.dart';
import 'features/events/presentation/controllers/events_controller.dart';
import 'features/events/presentation/screens/events_list_screen.dart';

class ThrottleMeetApp extends StatefulWidget {
  const ThrottleMeetApp({super.key});

  @override
  State<ThrottleMeetApp> createState() => _ThrottleMeetAppState();
}

class _ThrottleMeetAppState extends State<ThrottleMeetApp> {
  late final EventsController _controller;

  @override
  void initState() {
    super.initState();
    final participantIdStore = ParticipantIdStore();
    _controller = EventsController(
      repository: SupabaseEventsRepository(
        participantIdStore: participantIdStore,
        eventSnapshotCache: SharedPreferencesEventSnapshotCache(),
      ),
    );
    _controller.loadEvents();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThrottleMeet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: EventsListScreen(controller: _controller),
    );
  }
}
