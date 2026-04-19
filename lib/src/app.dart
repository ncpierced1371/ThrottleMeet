import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/events/data/repositories/in_memory_events_repository.dart';
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
    _controller = EventsController(
      repository: InMemoryEventsRepository(),
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
