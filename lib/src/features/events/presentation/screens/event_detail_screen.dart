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
          appBar: AppBar(title: const Text('Event')),
          body: event == null
              ? const AppEmptyState(
                  title: 'Event not found',
                  message: 'This event may have been removed or never existed.',
                )
              : _EventDetailBody(
                  event: event,
                  controller: controller,
                  onEdit: canManage ? () => _editEvent(context, event) : null,
                  onCancel: canManage
                      ? () => _confirmCancel(context, event)
                      : null,
                ),
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
  const _EventDetailBody({
    required this.event,
    required this.controller,
    this.onEdit,
    this.onCancel,
  });

  final Event event;
  final EventsController controller;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                _EventSchedule(startTime: event.startTime),
                if (event.status == EventStatus.cancelled) ...[
                  const SizedBox(height: 16),
                  const _CancelledEventBanner(),
                ],
                const SizedBox(height: 20),
                _EventFacts(event: event),
                const SizedBox(height: 16),
                _DescriptionSection(description: event.description),
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
                              _isUpdatingRsvp ||
                                  event.status == EventStatus.cancelled
                              ? null
                              : _updateRsvp,
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.onEdit != null && widget.onCancel != null) ...[
                  const SizedBox(height: 16),
                  _OrganizerControls(
                    onEdit: widget.onEdit!,
                    onCancel: widget.onCancel!,
                  ),
                ],
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

class _EventSchedule extends StatelessWidget {
  const _EventSchedule({required this.startTime});

  final DateTime startTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 20,
          color: colorScheme.secondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            DateTimeFormatter.shortDateTime(context, startTime),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventFacts extends StatelessWidget {
  const _EventFacts({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final attendeeLabel = event.attendeeCount == 1
        ? '1 attendee'
        : '${event.attendeeCount} attendees';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            _DetailRow(
              icon: Icons.place_outlined,
              label: 'Location',
              value: event.locationName,
            ),
            const Divider(height: 1),
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Organizer',
              value: event.hostName,
            ),
            const Divider(height: 1),
            _DetailRow(
              icon: Icons.group_outlined,
              label: 'Attendance',
              value: attendeeLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About this event', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizerControls extends StatelessWidget {
  const _OrganizerControls({required this.onEdit, required this.onCancel});

  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Organizer controls', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Manage the event details or cancel the event.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                Tooltip(
                  message: 'Edit event',
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Event'),
                  ),
                ),
                Tooltip(
                  message: 'Cancel event',
                  child: TextButton.icon(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    icon: const Icon(Icons.event_busy_outlined),
                    label: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 108,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
