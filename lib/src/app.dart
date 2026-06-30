import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/data/supabase_auth_gateway.dart';
import 'features/auth/data/supabase_profile_repository.dart';
import 'features/auth/presentation/controllers/auth_bootstrap_controller.dart';
import 'features/events/data/cache/event_snapshot_cache.dart';
import 'features/events/data/repositories/supabase_events_repository.dart';
import 'features/events/presentation/controllers/events_controller.dart';
import 'features/events/presentation/screens/events_list_screen.dart';

typedef EventsControllerFactory = EventsController Function();

class ThrottleMeetApp extends StatefulWidget {
  const ThrottleMeetApp({
    super.key,
    this.authBootstrapController,
    this.eventsControllerFactory,
  });

  final AuthBootstrapController? authBootstrapController;
  final EventsControllerFactory? eventsControllerFactory;

  @override
  State<ThrottleMeetApp> createState() => _ThrottleMeetAppState();
}

class _ThrottleMeetAppState extends State<ThrottleMeetApp> {
  late final AuthBootstrapController _authBootstrapController;
  late final bool _ownsAuthBootstrapController;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  EventsController? _eventsController;
  String? _eventsUserId;
  ProfileSyncStatus _lastProfileSyncStatus = ProfileSyncStatus.idle;

  @override
  void initState() {
    super.initState();
    _ownsAuthBootstrapController = widget.authBootstrapController == null;
    _authBootstrapController =
        widget.authBootstrapController ??
        AuthBootstrapController(
          authGateway: SupabaseAuthGateway(),
          profileRepository: SupabaseProfileRepository(),
        );
    _authBootstrapController.addListener(_handleAuthBootstrapChange);
    unawaited(Future<void>.microtask(_authBootstrapController.bootstrap));
  }

  void _handleAuthBootstrapChange() {
    if (!mounted) {
      return;
    }

    final authState = _authBootstrapController.state;
    final authenticatedUserId = _authBootstrapController.userId;
    if (authState == AuthBootstrapState.ready &&
        authenticatedUserId != null &&
        (_eventsController == null || _eventsUserId != authenticatedUserId)) {
      _eventsController?.dispose();
      _eventsController = _createEventsController();
      _eventsUserId = authenticatedUserId;
      unawaited(_eventsController!.loadEvents());
    } else if (authState == AuthBootstrapState.error) {
      _eventsController?.dispose();
      _eventsController = null;
      _eventsUserId = null;
    }

    _handleProfileSyncMessage();
    setState(() {});
  }

  EventsController _createEventsController() {
    return widget.eventsControllerFactory?.call() ?? _buildEventsController();
  }

  void _handleProfileSyncMessage() {
    final status = _authBootstrapController.profileSyncStatus;
    if (status == _lastProfileSyncStatus) {
      return;
    }
    _lastProfileSyncStatus = status;

    if (status == ProfileSyncStatus.error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scaffoldMessengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text(
                'Profile unavailable. Saved events are still available.',
              ),
              action: SnackBarAction(
                label: 'Retry profile',
                onPressed: () {
                  unawaited(_authBootstrapController.retryProfileSync());
                },
              ),
            ),
          );
      });
    } else if (status == ProfileSyncStatus.ready) {
      _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    }
  }

  EventsController _buildEventsController() {
    return EventsController(
      repository: SupabaseEventsRepository(
        eventSnapshotCache: SharedPreferencesEventSnapshotCache(),
      ),
    );
  }

  @override
  void dispose() {
    _authBootstrapController.removeListener(_handleAuthBootstrapChange);
    if (_ownsAuthBootstrapController) {
      _authBootstrapController.dispose();
    }
    _eventsController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'ThrottleMeet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: switch (_authBootstrapController.state) {
        AuthBootstrapState.initializing => const _AuthInitializingScreen(),
        AuthBootstrapState.ready => EventsListScreen(
          controller: _eventsController!,
        ),
        AuthBootstrapState.error => _AuthErrorScreen(
          onRetry: _authBootstrapController.bootstrap,
        ),
      },
    );
  }
}

class _AuthInitializingScreen extends StatelessWidget {
  const _AuthInitializingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unable to start ThrottleMeet.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
