import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../controllers/events_controller.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';
import '../widgets/event_card.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key, required this.controller});

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
          appBar: AppBar(
            title: const Text('ThrottleMeet'),
            actions: [
              IconButton(
                onPressed: controller.isLoading ? null : controller.loadEvents,
                tooltip: 'Refresh events',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
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
          body: controller.isLoading && controller.events.isEmpty
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
      if (controller.errorMessage != null) {
        return AppEmptyState(
          title: 'Unable to load events',
          message: controller.errorMessage!,
          action: FilledButton.icon(
            onPressed: controller.loadEvents,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        );
      }

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

    return Column(
      children: [
        if (controller.isLoading) const LinearProgressIndicator(),
        if (controller.errorMessage != null)
          _EventsLoadErrorBanner(controller: controller),
        Expanded(
          child: ListView.separated(
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
          ),
        ),
      ],
    );
  }
}

class _EventsLoadErrorBanner extends StatelessWidget {
  const _EventsLoadErrorBanner({required this.controller});

  final EventsController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                controller.errorMessage!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: controller.loadEvents,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
