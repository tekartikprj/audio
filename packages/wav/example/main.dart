// ignore_for_file: avoid_print

import 'dart:math';

import 'package:fs_shim/fs_shim.dart';
import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file.dart';
import 'package:tekartik_wav/wav_file_fs.dart';

/// [seconds] of a [frequency] sine at [sampleRate], samples from -1 to 1.
SoundBuffer sine(double frequency, {int sampleRate = 44100, num seconds = 1}) {
  var buffer = SoundBuffer(sampleRate, (sampleRate * seconds).round());
  for (var i = 0; i < buffer.length; i++) {
    buffer[i] = 0.5 * sin(2 * pi * frequency * i / sampleRate);
  }
  return buffer;
}

/// Writes, reads and mixes WAV files, in memory (every platform): use
/// `fileSystemIo` for real files on the VM and Flutter native.
Future<void> main() async {
  var fs = fileSystemMemory;

  // A stereo file: a 440 Hz left channel, 660 Hz right.
  var wav = WavFile()
    ..sampleRate = 44100
    ..numChannels = 2
    ..soundBuffers = [sine(440), sine(660)];
  await wav.writeFs(fs, 'stereo.wav');

  // Read it back.
  var read = await WavFile().readFs(fs, 'stereo.wav');
  print(
    'stereo.wav: ${read.numChannels} channels, ${read.sampleRate} Hz, '
    '${read.soundBuffers!.first.length} frames',
  );

  // Mix it with a mono file: the output gets 2 channels, the longest length.
  var mono = WavFile()
    ..sampleRate = 44100
    ..numChannels = 1
    ..soundBuffers = [sine(220, seconds: 2)];
  await mono.writeFs(fs, 'mono.wav');
  await mixWavFiles(
    fs,
    ['stereo.wav', 'mono.wav'],
    'mix.wav',
    algorithm: WavMixAlgorithm.normalized,
  );
  var mix = await WavFile().readFs(fs, 'mix.wav');
  print(
    'mix.wav: ${mix.numChannels} channels, '
    '${mix.soundBuffers!.first.length / mix.sampleRate!} s',
  );

  // Bad bytes: a FormatException.
  try {
    await WavFile().read(Stream.value([1, 2, 3]));
  } on FormatException catch (e) {
    print('not a wav file: ${e.message}');
  }
}
