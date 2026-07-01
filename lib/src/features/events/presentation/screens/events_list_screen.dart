import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../auth/presentation/controllers/auth_bootstrap_controller.dart';
import '../../../auth/presentation/screens/profile_edit_screen.dart';
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
      animation: Listenable.merge([controller, widget.authController]),
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
          body: Column(
            children: [
              if (_shouldPromptForProfile)
                _IncompleteProfilePrompt(onPressed: _openProfile),
              Expanded(
                child: controller.isLoading && controller.events.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _EventsListBody(controller: controller),
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _shouldPromptForProfile {
    final authController = widget.authController;
    return authController.profileSyncStatus == ProfileSyncStatus.ready &&
        !(authController.profile?.displayName?.trim().isNotEmpty ?? false);
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProfileEditScreen(authController: widget.authController),
      ),
    );
  }
}

class _IncompleteProfilePrompt extends StatelessWidget {
  const _IncompleteProfilePrompt({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.person_outline, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Add a display name for the beta.',
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
            ),
            TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSecondaryContainer,
              ),
              child: const Text('Complete profile'),
            ),
          ],
        ),
      ),
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

    final visibleEvents = controller.visibleEvents;

    return Column(
      children: [
        if (controller.isLoading) const LinearProgressIndicator(),
        if (controller.isShowingCachedEvents) const _CachedEventsBanner(),
        if (controller.errorMessage != null)
          _EventsLoadErrorBanner(controller: controller),
        _EventFilterControl(controller: controller),
        Expanded(
          child: visibleEvents.isEmpty
              ? _FilteredEventsEmptyState(filter: controller.selectedFilter)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: visibleEvents.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final event = visibleEvents[index];

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

class _EventFilterControl extends StatelessWidget {
  const _EventFilterControl({required this.controller});

  final EventsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SegmentedButton<EventListFilter>(
        segments: EventListFilter.values
            .map(
              (filter) => ButtonSegment<EventListFilter>(
                value: filter,
                label: Text(switch (filter) {
                  EventListFilter.all => 'All',
                  EventListFilter.upcoming => 'Upcoming',
                  EventListFilter.mine => 'Mine',
                }),
              ),
            )
            .toList(),
        selected: {controller.selectedFilter},
        showSelectedIcon: false,
        expandedInsets: EdgeInsets.zero,
        onSelectionChanged: (selection) {
          controller.selectFilter(selection.first);
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? colorScheme.secondary
                : colorScheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? colorScheme.onSecondary
                : colorScheme.onSurfaceVariant;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outlineVariant),
          ),
          textStyle: WidgetStatePropertyAll(
            theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          ),
        ),
      ),
    );
  }
}

class _FilteredEventsEmptyState extends StatelessWidget {
  const _FilteredEventsEmptyState({required this.filter});

  final EventListFilter filter;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: switch (filter) {
        EventListFilter.all => 'No events yet',
        EventListFilter.upcoming => 'No upcoming events',
        EventListFilter.mine => 'No events in Mine',
      },
      message: switch (filter) {
        EventListFilter.all =>
          'Create the first event and start building the community.',
        EventListFilter.upcoming =>
          'Check back soon for newly scheduled events.',
        EventListFilter.mine =>
          'Events you own, are going to, or are interested in appear here.',
      },
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
