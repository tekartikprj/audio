// Plays a techno loop computed here: 5 s through a bass and treble boost,
// then 5 s without it (the processor's bypass crossfades: no click at the
// switch). On the VM or in a browser, through tekartik_audio_play:
//
//     dart run example/eq_ab_play.dart
//     dart run tekartik_common_build:web_run example/eq_ab_play.dart
//     dart run tekartik_common_build:web_run --wasm example/eq_ab_play.dart
//
// The VM plays with pw-play, paplay or aplay on Linux, afplay on macOS,
// PowerShell on Windows; the browser through Web Audio (web_run: a headless
// Chrome, sound on). To keep the sound: example/eq_ab_wav.dart.
// ignore_for_file: avoid_print
import 'dart:async';

import 'package:tekartik_audio_play/audio_play.dart';

import 'src/techno_ab.dart';

Future<void> main() async {
  var sound = renderTechnoAb();
  print(
    'Techno loop, 10 s: 5 s with ${technoAbBoost.name} '
    '($technoAbBoostText), then 5 s without.',
  );
  print('▶ with ${technoAbBoost.name}');
  var switched = Timer(
    Duration(milliseconds: (technoAbHalf * 1000).round()),
    () => print('▶ without (bypass)'),
  );
  try {
    await audioPlaySamples([sound], sampleRate: technoAbSampleRate);
  } on AudioPlayException catch (e) {
    print('Not played: ${e.message} (example/eq_ab_wav.dart writes it)');
  } finally {
    switched.cancel();
  }
}
