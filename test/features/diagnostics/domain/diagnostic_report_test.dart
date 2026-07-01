import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/features/diagnostics/domain/diagnostic_report.dart';

void main() {
  test('generates a sanitized plain-text beta diagnostic report', () {
    final report = DiagnosticReport(
      appVersion: '1.0.0',
      buildNumber: '7',
      releaseChannel: 'beta',
      platform: 'macOS',
      authState: 'ready',
      profileState: 'error',
      eventCount: 5,
      cachedEventCount: 4,
      isShowingCachedEvents: true,
      latestSuccessfulEventRefresh: DateTime.utc(2026, 6, 30, 12),
      latestCacheWrite: DateTime.utc(2026, 6, 30, 11, 30),
    );

    final text = report.toPlainText();

    expect(text, contains('Version: 1.0.0'));
    expect(text, contains('Build: 7'));
    expect(text, contains('Release channel: beta'));
    expect(text, contains('Platform: macOS'));
    expect(text, contains('Auth state: ready'));
    expect(text, contains('Profile state: error'));
    expect(text, contains('Visible event count: 5'));
    expect(text, contains('Cached event count: 4'));
    expect(text, contains('Cache status: showing saved events'));
    expect(text, contains('2026-06-30T12:00:00.000Z'));
    expect(text, contains('2026-06-30T11:30:00.000Z'));
    expect(text.toLowerCase(), isNot(contains('supabase_key')));
    expect(text.toLowerCase(), isNot(contains('access_token')));
    expect(text.toLowerCase(), isNot(contains('refresh_token')));
  });

  test('reports unavailable timestamps without throwing', () {
    const report = DiagnosticReport(
      appVersion: '1.0.0',
      buildNumber: '1',
      releaseChannel: 'beta',
      platform: 'Android',
      authState: 'initializing',
      profileState: 'idle',
      eventCount: 0,
      cachedEventCount: 0,
      isShowingCachedEvents: false,
      latestSuccessfulEventRefresh: null,
      latestCacheWrite: null,
    );

    expect(report.cacheStatus, 'no saved snapshot recorded');
    expect(report.toPlainText(), contains('not available'));
  });
}
