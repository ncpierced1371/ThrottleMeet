import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../controllers/events_controller.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';
import '../widgets/event_card.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({
    super.key,
    required this.controller,
  });

  final EventsController controller;

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('ThrottleMeet')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreateEventScreen(controller: controller),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Event'),
          ),
          body: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _EventsListBody(controller: controller),
        );
      },
    );
  }
}

class _EventsListBody extends StatelessWidget {
  const _EventsListBody({required this.controller});

  final EventsController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.events.isEmpty) {
      return AppEmptyState(
        title: 'No events yet',
        message: 'Create the first event and start building the community.',
        action: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CreateEventScreen(controller: controller),
              ),
            );
          },
          child: const Text('Create Event'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: controller.events.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final event = controller.events[index];

        return EventCard(
          event: event,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EventDetailScreen(
                  controller: controller,
                  eventId: event.id,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
