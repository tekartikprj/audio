@TestOn('vm')
library;

import 'dart:typed_data';
import 'package:fs_shim/fs_shim.dart';
import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file.dart';
import 'package:tekartik_wav/wav_file_fs.dart';
import 'package:test/test.dart';

void main() {
  group('wav_file_fs', () {
    late FileSystem fs;

    setUp(() {
      fs = fileSystemMemory;
    });

    test('read/write round-trip', () async {
      var wav = WavFile()
        ..sampleRate = 44100
        ..numChannels = 1;

      var sb = SoundBuffer(44100, 100);
      for (var i = 0; i < 100; i++) {
        sb[i] = i / 100.0;
      }
      wav.soundBuffers = [sb];

      var path = 'test.wav';
      await wav.writeFs(fs, path);

      expect(await fs.isFile(path), isTrue);

      var readWav = WavFile();
      await readWav.readFs(fs, path);

      expect(readWav.sampleRate, equals(44100));
      expect(readWav.numChannels, equals(1));
      expect(readWav.soundBuffers!.length, equals(1));
      expect(readWav.soundBuffers![0].length, equals(100));

      for (var i = 0; i < 100; i++) {
        // Since we write as 16-bit PCM and convert back, check with a tolerance
        expect(readWav.soundBuffers![0][i], closeTo(i / 100.0, 0.001));
      }
    });

    test('mixWavFiles', () async {
      // Create three source files with different durations/contents
      var path1 = 'file1.wav';
      var path2 = 'file2.wav';
      var outPath = 'mixed.wav';

      // File 1: Length 2, Sample rate 22050, 1 channel (mono)
      // values: [0.1, 0.5]
      var wav1 = WavFile()
        ..sampleRate = 22050
        ..numChannels = 1
        ..soundBuffers = [
          SoundBuffer.fromData(22050, Float32List.fromList([0.1, 0.5])),
        ];
      await wav1.writeFs(fs, path1);

      // File 2: Length 3, Sample rate 22050, 2 channels (stereo)
      // channel 0 values: [0.2, -0.1, 0.8]
      // channel 1 values: [0.3, 0.4, -0.6]
      var wav2 = WavFile()
        ..sampleRate = 22050
        ..numChannels = 2
        ..soundBuffers = [
          SoundBuffer.fromData(22050, Float32List.fromList([0.2, -0.1, 0.8])),
          SoundBuffer.fromData(22050, Float32List.fromList([0.3, 0.4, -0.6])),
        ];
      await wav2.writeFs(fs, path2);

      // Mix them using clamping
      await mixWavFiles(
        fs,
        [path1, path2],
        outPath,
        algorithm: WavMixAlgorithm.clamped,
      );

      var mixed = WavFile();
      await mixed.readFs(fs, outPath);

      // Output should have 2 channels (max of 1 and 2)
      expect(mixed.numChannels, equals(2));
      expect(mixed.sampleRate, equals(22050));

      // Output length should be 3 (max of 2 and 3)
      expect(mixed.soundBuffers![0].length, equals(3));
      expect(mixed.soundBuffers![1].length, equals(3));

      // Expected Channel 0 (mix of [0.1, 0.5, 0.0] and [0.2, -0.1, 0.8]):
      // idx 0: 0.1 + 0.2 = 0.3
      // idx 1: 0.5 + -0.1 = 0.4
      // idx 2: 0.0 + 0.8 = 0.8
      expect(mixed.soundBuffers![0][0], closeTo(0.3, 0.005));
      expect(mixed.soundBuffers![0][1], closeTo(0.4, 0.005));
      expect(mixed.soundBuffers![0][2], closeTo(0.8, 0.005));

      // Expected Channel 1 (mix of [0.0, 0.0, 0.0] and [0.3, 0.4, -0.6]):
      // idx 0: 0.3
      // idx 1: 0.4
      // idx 2: -0.6
      expect(mixed.soundBuffers![1][0], closeTo(0.3, 0.005));
      expect(mixed.soundBuffers![1][1], closeTo(0.4, 0.005));
      expect(mixed.soundBuffers![1][2], closeTo(-0.6, 0.005));
    });

    test('mixWavFiles mismatched sample rate throws', () async {
      var path1 = 'file1.wav';
      var path2 = 'file2.wav';

      var wav1 = WavFile()
        ..sampleRate = 22050
        ..numChannels = 1
        ..soundBuffers = [
          SoundBuffer.fromData(22050, Float32List.fromList([0.1])),
        ];
      await wav1.writeFs(fs, path1);

      var wav2 = WavFile()
        ..sampleRate = 44100
        ..numChannels = 1
        ..soundBuffers = [
          SoundBuffer.fromData(44100, Float32List.fromList([0.2])),
        ];
      await wav2.writeFs(fs, path2);

      expect(
        () => mixWavFiles(fs, [path1, path2], 'out.wav'),
        throwsArgumentError,
      );
    });
  });
}
