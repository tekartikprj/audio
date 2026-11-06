import 'package:tekartik_pitch_web_worker/setup.dart';

/// Builds web/pitch_worker.js: `dart run tekartik_pitch_web_worker:setup`.
Future<void> main(List<String> arguments) =>
    pitchWorkerScript.setupMain(arguments);
