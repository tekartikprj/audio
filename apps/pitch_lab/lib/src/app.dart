import 'package:material_ui/material_ui.dart';
import 'package:tekaly_file_picker_flutter/file_picker_flutter.dart';
import 'package:tekartik_audio_input_record/audio_input_record.dart';

import 'controller.dart';
import 'lab_screen.dart';
import 'sounds.dart';

/// Runs the lab; the [demo] starts on a test sound at once.
Future<void> runPitchLab({bool demo = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  initTekalyFilePickerFlutter();
  var controller = PitchLabController(microphone: AudioInputMicrophone());
  if (demo) {
    await controller.setSource(LabTestSound(labSounds.first), start: true);
  }
  runApp(PitchLabApp(controller: controller));
}

/// The lab app.
class PitchLabApp extends StatelessWidget {
  /// The state of the lab.
  final PitchLabController controller;

  /// The app of [controller].
  const PitchLabApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2B6CB0),
        brightness: brightness,
      ),
    );
    return MaterialApp(
      title: 'Pitch lab',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: LabScreen(controller: controller),
    );
  }
}
