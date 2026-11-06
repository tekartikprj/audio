import 'src/app.dart';

/// The demo: the lab playing a test sound (an accordion musette) at once,
/// no microphone needed to see it work.
///
/// ```sh
/// flutter run -d chrome -t lib/main_demo.dart
/// tkhostelio deploy-demo   # site pitch_lab_demo on tkhostelio-dev
/// ```
Future<void> main() => runPitchLab(demo: true);
