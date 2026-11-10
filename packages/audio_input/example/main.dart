// ignore_for_file: avoid_print

import 'dart:math';
import 'dart:typed_data';

import 'package:tekartik_audio_input/audio_input.dart';
import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file_fs.dart';

/// [seconds] of a [frequency] sine at [sampleRate], [amplitude] at most 1.
Float32List sine(
  double frequency, {
  required int sampleRate,
  double seconds = 1,
  double amplitude = 0.5,
}) => Float32List.fromList([
  for (var i = 0; i < (seconds * sampleRate).round(); i++)
    amplitude * sin(2 * pi * frequency * i / sampleRate),
]);

/// Reads [input] to its end, printing the level of each chunk.
Future<void> printLevels(AudioInput input) async {
  var metered = AudioInputMetered(input);
  var count = 0;
  await for (var chunk in await metered.start()) {
    count += chunk.length;
    print('  $count samples: ${metered.level}');
  }
  await metered.close();
}

Future<void> main() async {
  const sampleRate = 8000;

  // Samples as an input, as fast as possible (speed 1 is real time).
  print('samples:');
  await printLevels(
    AudioInputSamples(
      sine(440, sampleRate: sampleRate, seconds: 0.5),
      sampleRate: sampleRate,
      speed: 0,
      chunkSize: 1024,
    ),
  );

  // A WAV file (here made in memory): 16 bit PCM, channels mixed to mono.
  var wav = writeWavBytes(
    sampleRate: sampleRate,
    numChannels: 1,
    soundBuffers: [
      SoundBuffer.fromData(
        sampleRate,
        sine(220, sampleRate: sampleRate, seconds: 0.25, amplitude: 1),
      ),
    ],
  );
  print('wav file:');
  await printLevels(AudioInputSamples.wav(wav, speed: 0));

  // Not a WAV file: a FormatException.
  try {
    AudioInputSamples.wav(Uint8List.fromList([1, 2, 3]));
  } on FormatException catch (e) {
    print('not a wav: ${e.message}');
  }

  // Pushed by hand (tests, samples coming from elsewhere).
  var push = AudioInputPush(sampleRate: sampleRate);
  var chunks = (await push.start()).toList();
  push
    ..push(sine(440, sampleRate: sampleRate, seconds: 0.1))
    ..push(Float32List(800));
  await push.stop();
  print('pushed: ${(await chunks).map((chunk) => chunk.length).toList()}');
}
