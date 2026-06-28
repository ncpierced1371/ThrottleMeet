import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/features/events/data/repositories/in_memory_events_repository.dart';
import 'package:throttlemeet_v2/src/features/events/presentation/controllers/events_controller.dart';
import 'package:throttlemeet_v2/src/features/events/presentation/screens/events_list_screen.dart';

void main() {
  testWidgets('shows events without a live backend', (tester) async {
    final controller = EventsController(repository: InMemoryEventsRepository());
    addTearDown(controller.dispose);
    await controller.loadEvents();

    await tester.pumpWidget(
      MaterialApp(home: EventsListScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ThrottleMeet'), findsOneWidget);
    expect(find.text('Spring Canyon Run'), findsOneWidget);
    expect(find.text('Create Event'), findsOneWidget);
  });
}
