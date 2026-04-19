import 'package:flutter/material.dart';

import '../../features/events/presentation/screens/create_event_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import 'app_routes.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.eventsList:
        return MaterialPageRoute<void>(
          builder: (_) => const EventsListScreen(),
          settings: settings,
        );
      case AppRoutes.createEvent:
        return MaterialPageRoute<void>(
          builder: (_) => const CreateEventScreen(),
          settings: settings,
        );
      case AppRoutes.eventDetail:
        final eventId = settings.arguments as String?;

        return MaterialPageRoute<void>(
          builder: (_) => EventDetailScreen(eventId: eventId ?? ''),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('ThrottleMeet')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unknown route: ${settings.name}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          settings: settings,
        );
    }
  }

  static void openCreateEvent(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.createEvent);
  }

  static void openEventDetail(BuildContext context, String eventId) {
    Navigator.of(context).pushNamed(AppRoutes.eventDetail, arguments: eventId);
  }
}
