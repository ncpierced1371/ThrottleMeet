import 'package:flutter/material.dart';

import '../../../../app_scope.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../controllers/events_controller.dart';
import '../widgets/event_card.dart';

class EventsListScreen extends StatelessWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).eventsController;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('ThrottleMeet')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => AppRouter.openCreateEvent(context),
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
          onPressed: () => AppRouter.openCreateEvent(context),
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
          onTap: () => AppRouter.openEventDetail(context, event.id),
        );
      },
    );
  }
}
