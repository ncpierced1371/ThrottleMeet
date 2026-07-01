import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../auth/presentation/controllers/auth_bootstrap_controller.dart';
import '../../../diagnostics/presentation/screens/diagnostics_screen.dart';
import '../controllers/events_controller.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';
import '../widgets/event_card.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({
    super.key,
    required this.controller,
    required this.authController,
  });

  final EventsController controller;
  final AuthBootstrapController authController;

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
            title: const _EventsHeaderTitle(),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DiagnosticsScreen(
                        authController: widget.authController,
                        eventsController: controller,
                      ),
                    ),
                  );
                },
                tooltip: 'Diagnostics',
                icon: const Icon(Icons.info_outline),
              ),
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

class _EventsHeaderTitle extends StatelessWidget {
  const _EventsHeaderTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Throttle Meet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Discover local automotive events',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimary.withValues(alpha: 0.72),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
            height: 1.15,
          ),
        ),
      ],
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
        if (controller.isShowingCachedEvents) const _CachedEventsBanner(),
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

class _CachedEventsBanner extends StatelessWidget {
  const _CachedEventsBanner();

  @override
  Widget build(BuildContext context) {
    final semanticColors = AppSemanticColors.of(context);

    return Material(
      color: semanticColors.warningContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.offline_pin_outlined,
              size: 19,
              color: semanticColors.warning,
            ),
            const SizedBox(width: 10),
            Text(
              'Showing saved events',
              style: TextStyle(
                color: semanticColors.onWarningContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 19, color: colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.errorMessage!,
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: controller.loadEvents,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onErrorContainer,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
