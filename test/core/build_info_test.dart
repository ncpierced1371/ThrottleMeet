import 'package:flutter_test/flutter_test.dart';
import 'package:throttlemeet_v2/src/core/build_info.dart';

void main() {
  test('exposes beta release identity from one source', () {
    expect(BuildInfo.version, '1.0.0');
    expect(BuildInfo.buildNumber, '1');
    expect(BuildInfo.releaseChannel, 'beta');
    expect(BuildInfo.versionWithBuild, '1.0.0+1');
  });
}
