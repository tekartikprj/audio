import 'package:tekartik_common_build/web_run.dart';
import 'package:tekartik_pitch_web_worker/setup.dart';

/// Runs example/pitch_worker_example.dart in a headless Chrome, its worker
/// next to the page: builds example/pitch_worker.js (git-ignored; again only
/// when the SDK or a package changed), then serves it with the page.
///
///     dart run tool/example_web_run.dart          # dart2js
///     dart run tool/example_web_run.dart --wasm   # dart2wasm
Future<void> main(List<String> arguments) async {
  await setupPitchWorker(dir: 'example');
  await webRun(
    'example/pitch_worker_example.dart',
    compiler: arguments.contains('--wasm')
        ? WebRunCompiler.wasm
        : WebRunCompiler.js,
    files: {pitchWorkerJsFilename: 'example/$pitchWorkerJsFilename'},
    chromeArguments: ['--mute-audio'],
  );
}
