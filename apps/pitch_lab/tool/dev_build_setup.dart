import 'package:tekartik_pitch_web_worker/setup.dart';

/// Builds web/pitch_worker.js, the analyses in a web worker (run_ci runs
/// this before the tests and the build; run it before `tkhostelio
/// deploy-demo`).
Future<void> main() => setupPitchWorker();
