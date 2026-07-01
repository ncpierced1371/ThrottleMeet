import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/build_info.dart';
import '../../../../core/platform/platform_info.dart';
import '../../../auth/presentation/controllers/auth_bootstrap_controller.dart';
import '../../../events/presentation/controllers/events_controller.dart';
import '../../domain/diagnostic_report.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({
    super.key,
    required this.authController,
    required this.eventsController,
  });

  final AuthBootstrapController authController;
  final EventsController eventsController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([authController, eventsController]),
      builder: (context, _) {
        final report = _buildReport();
        return Scaffold(
          appBar: AppBar(title: const Text('Settings & About')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'ThrottleMeet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Version ${BuildInfo.versionWithBuild} '
                '• ${BuildInfo.releaseChannel} • ${PlatformInfo.current}',
              ),
              const SizedBox(height: 24),
              Text(
                'Beta diagnostics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _DiagnosticRow(
                label: 'Authenticated user ID',
                value: authController.userId ?? 'Not available',
                selectable: true,
              ),
              _DiagnosticRow(
                label: 'Auth state',
                value: authController.authState.name,
              ),
              _DiagnosticRow(
                label: 'Profile sync state',
                value: authController.profileSyncStatus.name,
              ),
              _DiagnosticRow(label: 'Platform', value: report.platform),
              _DiagnosticRow(
                label: 'App version',
                value: '${report.appVersion}+${report.buildNumber}',
              ),
              _DiagnosticRow(
                label: 'Release channel',
                value: report.releaseChannel,
              ),
              _DiagnosticRow(
                label: 'Cached events',
                value: '${report.cachedEventCount}',
              ),
              _DiagnosticRow(label: 'Cache status', value: report.cacheStatus),
              _DiagnosticRow(
                label: 'Latest successful event refresh',
                value: _formatTimestamp(report.latestSuccessfulEventRefresh),
              ),
              _DiagnosticRow(
                label: 'Latest cache write',
                value: _formatTimestamp(report.latestCacheWrite),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _copyReport(context, report),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy diagnostic report'),
              ),
              const SizedBox(height: 8),
              const Text(
                'The report excludes Supabase keys, access tokens, and session tokens.',
              ),
            ],
          ),
        );
      },
    );
  }

  DiagnosticReport _buildReport() {
    return DiagnosticReport(
      appVersion: BuildInfo.version,
      buildNumber: BuildInfo.buildNumber,
      releaseChannel: BuildInfo.releaseChannel,
      platform: PlatformInfo.current,
      authState: authController.authState.name,
      profileState: authController.profileSyncStatus.name,
      eventCount: eventsController.events.length,
      cachedEventCount: eventsController.cachedEventCount,
      isShowingCachedEvents: eventsController.isShowingCachedEvents,
      latestSuccessfulEventRefresh:
          eventsController.latestSuccessfulEventRefreshAt,
      latestCacheWrite: eventsController.latestCacheWriteAt,
    );
  }

  Future<void> _copyReport(
    BuildContext context,
    DiagnosticReport report,
  ) async {
    await Clipboard.setData(ClipboardData(text: report.toPlainText()));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Diagnostic report copied.')));
  }

  static String _formatTimestamp(DateTime? value) {
    return value?.toUtc().toIso8601String() ?? 'Not available';
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            if (selectable) SelectableText(value) else Text(value),
          ],
        ),
      ),
    );
  }
}
