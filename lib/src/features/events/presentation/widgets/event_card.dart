import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../domain/entities/event.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: colorScheme.secondary),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateTimeFormatter.shortDateTime(
                                context,
                                event.startTime,
                              ),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (event.viewerRsvpStatus != null) ...[
                        const SizedBox(width: 10),
                        Chip(
                          label: Text(event.viewerRsvpStatus!.label),
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -2,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _EventMetadata(
                    locationName: event.locationName,
                    hostName: event.hostName,
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  const SizedBox(height: 9),
                  _AttendeeCount(count: event.attendeeCount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventMetadata extends StatelessWidget {
  const _EventMetadata({required this.locationName, required this.hostName});

  final String locationName;
  final String hostName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 480;
        final itemWidth = useTwoColumns
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            SizedBox(
              width: itemWidth,
              child: _CompactInfoRow(
                icon: Icons.place_outlined,
                label: locationName,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _CompactInfoRow(
                icon: Icons.person_outline,
                label: hostName,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompactInfoRow extends StatelessWidget {
  const _CompactInfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 17, color: colorScheme.secondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendeeCount extends StatelessWidget {
  const _AttendeeCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = count == 1 ? '1 attendee' : '$count attendees';

    return Row(
      children: [
        Icon(Icons.group_outlined, size: 18, color: colorScheme.secondary),
        const SizedBox(width: 7),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
