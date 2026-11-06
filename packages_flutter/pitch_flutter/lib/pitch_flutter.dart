/// Flutter parts of pitch analysis: [PitchListening] runs `tekartik_pitch`
/// analyses on an audio input (its level measured for the widgets of
/// `tekartik_audio_input_flutter`, re-exported); widgets show the results
/// ([PitchGauge], [PitchReedsView], [PitchStringsView],
/// [PitchListeningControl]) with the theme's colors ([PitchColors]).
library;

export 'package:tekartik_audio_input_flutter/audio_input_flutter.dart';
export 'package:tekartik_pitch/pitch.dart';

export 'src/colors.dart';
export 'src/gauge.dart';
export 'src/listening.dart';
export 'src/listening_control.dart';
export 'src/reeds_view.dart';
export 'src/strings_view.dart';
