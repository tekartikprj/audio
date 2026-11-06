import 'package:tekartik_pitch_web_worker/setup.dart';

/// Builds test/pitch_worker.js, the worker of the browser tests (run_ci runs
/// this before the tests).
Future<void> main() => setupPitchWorker(dir: 'test');
