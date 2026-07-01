import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/rsvp_status.dart';
import '../controllers/events_controller.dart';
import '../widgets/rsvp_selector.dart';
import 'create_event_screen.dart';

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

        final canManage =
            event?.isOwnedByViewer == true &&
            event?.status == EventStatus.active;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Event Detail'),
            actions: canManage
                ? [
                    IconButton(
                      onPressed: () => _editEvent(context, event!),
                      tooltip: 'Edit event',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => _confirmCancel(context, event!),
                      tooltip: 'Cancel event',
                      icon: const Icon(Icons.event_busy_outlined),
                    ),
                  ]
                : null,
          ),
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

  Future<void> _editEvent(BuildContext context, Event event) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CreateEventScreen(controller: controller, eventToEdit: event),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: const Text(
          'The event will remain visible, but RSVPs and editing will be disabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Event'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel Event'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final succeeded = await controller.cancelEvent(event.id);
    if (!context.mounted) {
      return;
    }
    final message = succeeded
        ? 'Event cancelled.'
        : controller.errorMessage ?? 'Unable to cancel event.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EventDetailBody extends StatefulWidget {
  const _EventDetailBody({required this.event, required this.controller});

  final Event event;
  final EventsController controller;

  @override
  State<_EventDetailBody> createState() => _EventDetailBodyState();
}

class _EventDetailBodyState extends State<_EventDetailBody> {
  bool _isUpdatingRsvp = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = widget.event;
    final viewerRsvpStatus = event.viewerRsvpStatus;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (event.status == EventStatus.cancelled) ...[
          const _CancelledEventBanner(),
          const SizedBox(height: 16),
        ],
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
                  event.status == EventStatus.cancelled
                      ? 'RSVP changes are disabled for cancelled events.'
                      : viewerRsvpStatus == null
                      ? 'You have not responded yet.'
                      : 'Your current status is ${viewerRsvpStatus.label.toLowerCase()}.',
                ),
                const SizedBox(height: 16),
                RsvpSelector(
                  selected: viewerRsvpStatus,
                  onSelected:
                      _isUpdatingRsvp || event.status == EventStatus.cancelled
                      ? null
                      : _updateRsvp,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateRsvp(RsvpStatus status) async {
    if (_isUpdatingRsvp) {
      return;
    }

    setState(() {
      _isUpdatingRsvp = true;
    });

    final succeeded = await widget.controller.updateRsvp(
      eventId: widget.event.id,
      status: status,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isUpdatingRsvp = false;
    });

    final message = succeeded
        ? 'RSVP updated to ${status.label}.'
        : widget.controller.errorMessage ?? 'Unable to update RSVP.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CancelledEventBanner extends StatelessWidget {
  const _CancelledEventBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.event_busy_outlined,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cancelled event',
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
