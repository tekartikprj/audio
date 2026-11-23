// Plays one second of a 440 Hz tone (quiet), on the VM or in a browser:
//
//     dart run example/audio_play_example.dart
//     dart run tekartik_common_build:web_run example/audio_play_example.dart
//     dart run tekartik_common_build:web_run --wasm example/audio_play_example.dart
// ignore_for_file: avoid_print
import 'dart:math';
import 'dart:typed_data';

import 'package:tekartik_audio_play/audio_play.dart';

Future<void> main() async {
  const sampleRate = 48000;
  var tone = Float32List.fromList([
    for (var i = 0; i < sampleRate; i++)
      0.2 * sin(2 * pi * 440 * i / sampleRate),
  ]);
  print('Playing 1 s of 440 Hz');
  await audioPlaySamples([tone], sampleRate: sampleRate);
  print('Played');
}
