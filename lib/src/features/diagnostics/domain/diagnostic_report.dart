class DiagnosticReport {
  const DiagnosticReport({
    required this.appVersion,
    required this.buildNumber,
    required this.releaseChannel,
    required this.platform,
    required this.authState,
    required this.profileState,
    required this.eventCount,
    required this.cachedEventCount,
    required this.isShowingCachedEvents,
    required this.latestSuccessfulEventRefresh,
    required this.latestCacheWrite,
  });

  final String appVersion;
  final String buildNumber;
  final String releaseChannel;
  final String platform;
  final String authState;
  final String profileState;
  final int eventCount;
  final int cachedEventCount;
  final bool isShowingCachedEvents;
  final DateTime? latestSuccessfulEventRefresh;
  final DateTime? latestCacheWrite;

  String get cacheStatus {
    if (isShowingCachedEvents) {
      return 'showing saved events';
    }
    if (cachedEventCount > 0) {
      return 'saved snapshot available; showing fresh events';
    }
    return 'no saved snapshot recorded';
  }

  String toPlainText() {
    return [
      'Throttle Meet Beta Diagnostics',
      'Version: $appVersion',
      'Build: $buildNumber',
      'Release channel: $releaseChannel',
      'Platform: $platform',
      'Auth state: $authState',
      'Profile state: $profileState',
      'Visible event count: $eventCount',
      'Cached event count: $cachedEventCount',
      'Cache status: $cacheStatus',
      'Latest successful event refresh: '
          '${_formatTimestamp(latestSuccessfulEventRefresh)}',
      'Latest cache write: ${_formatTimestamp(latestCacheWrite)}',
      'Secrets and session tokens are intentionally excluded.',
    ].join('\n');
  }

  static String _formatTimestamp(DateTime? value) {
    return value?.toUtc().toIso8601String() ?? 'not available';
  }
}
