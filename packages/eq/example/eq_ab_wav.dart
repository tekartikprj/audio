// Writes the sound of eq_ab_play.dart to a WAV file (VM):
//
//     dart run example/eq_ab_wav.dart techno_ab.wav
import 'dart:io';

import 'package:tekartik_audio_play/audio_play.dart';

import 'src/techno_ab.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('eq_ab_wav <out.wav>');
    exitCode = 64;
    return;
  }
  await File(args.first).writeAsBytes(
    audioSamplesToWavBytes([renderTechnoAb()], sampleRate: technoAbSampleRate),
  );
  stdout.writeln('${args.first}: 5 s with ${technoAbBoost.name}, 5 s without');
}
