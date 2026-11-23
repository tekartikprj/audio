@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';
import 'package:tekartik_audio_eq/audio_eq.dart';
import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file.dart';
import 'package:tekartik_wav/wav_file_fs.dart';
import 'package:test/test.dart';

import '../bin/eq_wav.dart' as eq_wav;

void main() {
  test('eq_wav applies a JSON preset to a WAV file', () async {
    var dir = await Directory.systemTemp.createTemp('eq_wav');
    addTearDown(() => dir.delete(recursive: true));
    const rate = 48000;
    var sine = SoundBuffer(rate, rate);
    for (var i = 0; i < sine.length; i++) {
      sine[i] = 0.25 * sin(2 * pi * 1000 * i / rate);
    }
    var input = join(dir.path, 'in.wav');
    var output = join(dir.path, 'out.wav');
    var preset = join(dir.path, 'preset.json');
    await File(input).writeAsBytes(
      writeWavBytes(sampleRate: rate, numChannels: 1, soundBuffers: [sine]),
    );
    await File(preset).writeAsString(
      jsonEncode(EqPreset(bands: const [EqBand.peaking(1000, 6)]).toJson()),
    );
    await eq_wav.main([input, output, '--preset', preset]);
    expect(exitCode, 0);
    var result = WavFile();
    await result.read(File(output).openRead());
    var data = result.soundBuffers!.single.data;
    var peak = 0.0;
    for (var i = rate ~/ 2; i < data.length; i++) {
      peak = max(peak, data[i].abs());
    }
    // +6 dB: about twice the amplitude.
    expect(peak, closeTo(0.25 * eqDbToLinear(6), 0.002));
  });
}
