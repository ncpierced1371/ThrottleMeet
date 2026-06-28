import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/rsvp_status.dart';
import '../controllers/events_controller.dart';
import '../widgets/rsvp_selector.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({
    super.key,
    required this.controller,
    required this.eventId,
  });

  final EventsController controller;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final event = controller.getEventById(eventId);

        return Scaffold(
          appBar: AppBar(title: const Text('Event Detail')),
          body: event == null
              ? const AppEmptyState(
                  title: 'Event not found',
                  message: 'This event may have been removed or never existed.',
                )
              : _EventDetailBody(event: event, controller: controller),
        );
      },
    );
  }
}

class _EventDetailBody extends StatelessWidget {
  const _EventDetailBody({required this.event, required this.controller});

  final Event event;
  final EventsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewerRsvpStatus = event.viewerRsvpStatus;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(event.description, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 20),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'When',
                  value: DateTimeFormatter.shortDateTime(
                    context,
                    event.startTime,
                  ),
                ),
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: 'Where',
                  value: event.locationName,
                ),
                _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Host',
                  value: event.hostName,
                ),
                _DetailRow(
                  icon: Icons.group_outlined,
                  label: 'Attendees',
                  value: '${event.attendeeCount}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RSVP', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  viewerRsvpStatus == null
                      ? 'You have not responded yet.'
                      : 'Your current status is ${viewerRsvpStatus.label.toLowerCase()}.',
                ),
                const SizedBox(height: 16),
                RsvpSelector(
                  selected: viewerRsvpStatus,
                  onSelected: (status) =>
                      _updateRsvp(context, controller, event.id, status),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateRsvp(
    BuildContext context,
    EventsController controller,
    String eventId,
    RsvpStatus status,
  ) async {
    final succeeded = await controller.updateRsvp(
      eventId: eventId,
      status: status,
    );

    if (!context.mounted) {
      return;
    }

    final message = succeeded
        ? 'RSVP updated to ${status.label}.'
        : controller.errorMessage ?? 'Unable to update RSVP.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
