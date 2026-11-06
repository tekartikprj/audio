/// The setup step building the worker script of an app (dart:io).
library;

import 'package:tekartik_web_worker_build/web_worker_build.dart';

import 'protocol.dart';

const _package = 'tekartik_pitch_web_worker';

/// The worker script: `pitch_worker.js`, the analyses of tekartik_pitch
/// compiled with dart2js.
const pitchWorkerScript = WebWorkerScript(
  package: _package,
  filename: pitchWorkerJsFilename,
  entry: 'package:$_package/src/worker_main.dart',
  output: _pitchWorkerOutput,
);

String _pitchWorkerOutput(String js, ProjectPackages packages) =>
    '''
// Web worker of $_package ${packages.version(_package)}, built by
// `dart run $_package:setup`. Do not edit.
$js''';

/// Builds `pitch_worker.js` for the app at [path] (the current directory by
/// default) when needed (a new Dart SDK, a package of the worker changed),
/// and writes it as [filename] in its [dir] folder (`web`).
///
/// Called from the `tool/dev_build_setup.dart` of the app, that `run_ci`
/// runs before the tests and the build.
Future<WebWorkerScriptSetupResult> setupPitchWorker({
  String? path,
  String dir = 'web',
  String? filename,
  bool force = false,
  bool verbose = false,
}) => pitchWorkerScript.setup(
  path: path,
  dir: dir,
  filename: filename,
  force: force,
  verbose: verbose,
);
