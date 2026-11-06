@TestOn('vm')
library;

import 'package:tekartik_pitch_web_worker/setup.dart';
import 'package:test/test.dart';

void main() {
  // Also builds the worker that test/processor_test.dart loads in Chrome
  // (tool/dev_build_setup.dart, run by run_ci before the tests, does too).
  test('builds the worker once', () async {
    var result = await setupPitchWorker(dir: 'test');
    var segments = result.file.uri.pathSegments;
    expect(segments.sublist(segments.length - 2), [
      'test',
      pitchWorkerJsFilename,
    ]);
    var js = await result.file.readAsString();
    expect(js, startsWith('// Web worker of tekartik_pitch_web_worker'));
    var packages = (result.key['packages'] as Map).keys;
    expect(
      packages,
      containsAll(['tekartik_pitch_web_worker', 'tekartik_pitch', 'web']),
    );
    // Again: nothing to build.
    expect((await setupPitchWorker(dir: 'test')).built, isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
