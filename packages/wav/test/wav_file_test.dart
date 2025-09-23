@TestOn('vm')
library;

//import 'dart:async';
import 'dart:typed_data';

import 'package:tekartik_wav/wav_file.dart';
import 'package:test/test.dart';

void main() {
  group('header', () {
    test('simple sync', () {});
    //    test('read file basic', () {
    //
    //      File file = new File('../../../../hg/assets/sound/guitar/d_pick.wav');
    //      file.openRead().listen((Uint8List data) {
    //        // print(data.length);
    //        //print(data);
    //      },
    //      onError: (e) {
    //        print(e);
    //      },
    //      onDone:() {
    //        print('Done');
    //
    //      });
    //    });

    //    test('read header part', () {
    //      Uint8List header = new Uint8List.fromList([82, 73, 70, 70, 36, 147, 6, 0, 87, 65, 86, 69]);
    //
    //      WavFile wavFile = new WavFile();
    //      wavFile.feed(header);
    //
    //    });

    test('read header basic', () {
      var header = Uint8List.fromList([
        82,
        73,
        70,
        70,
        0,
        0,
        0,
        0,
        87,
        65,
        86,
        69,
      ]);

      var wavFile = WavFile();
      expect(wavFile.totalChunkSize, isNull);
      wavFile.feed(header);
      expect(wavFile.totalChunkSize, equals(0));
    });

    test('read chunk1 header', () {
      var header = Uint8List.fromList([
        82,
        73,
        70,
        70,
        0,
        0,
        0,
        0,
        87,
        65,
        86,
        69,
        0x66,
        0x6d,
        0x74,
        0x20,
        0,
        0,
        0,
        0,
      ]);

      var wavFile = WavFile();
      expect(wavFile.chunkSize, isNull);
      wavFile.feed(header);
      expect(wavFile.chunkSize, equals(0));
    });

    test('read chunk1', () {
      var header = Uint8List.fromList([
        0x52,
        0x49,
        0x46,
        0x46,
        0x24,
        0x08,
        0x00,
        0x00,
        0x57,
        0x41,
        0x56,
        0x45,
        0x66,
        0x6d,
        0x74,
        0x20,
        0x10,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x02,
        0x00,
        0x22,
        0x56,
        0x00,
        0x00,
        0x88,
        0x58,
        0x01,
        0x00,
        0x04,
        0x00,
        0x10,
        0x00,
      ]);

      var wavFile = WavFile();
      expect(wavFile.sampleRate, isNull);
      wavFile.feed(header);
      expect(wavFile.sampleRate, equals(22050));
      expect(wavFile.bitsPerSample, equals(16));
      expect(wavFile.numChannels, equals(2));
      expect(wavFile.audioFormat, equals(1));

      assert(!wavFile.done);
    });

    test('read sample', () {
      var header = Uint8List.fromList([
        0x52,
        0x49,
        0x46,
        0x46,
        0x24,
        0x08,
        0x00,
        0x00,
        0x57,
        0x41,
        0x56,
        0x45,
        0x66,
        0x6d,
        0x74,
        0x20,
        0x10,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x02,
        0x00,
        0x22,
        0x56,
        0x00,
        0x00,
        0x88,
        0x58,
        0x01,
        0x00,
        0x04,
        0x00,
        0x10,
        0x00,
        0x64, 0x61, 0x74, 0x61, // data
        0x1c, 0x00, 0x00, 0x00, // size
        0x00,
        0x00,
        0x00,
        0x00,
        0x24,
        0x17,
        0x1e,
        0xf3,
        0x3c,
        0x13,
        0x3c,
        0x14,
        0x16,
        0xf9,
        0x18,
        0xf9,
        0x34,
        0xe7,
        0x23,
        0xa6,
        0x3c,
        0xf2,
        0x24,
        0xf2,
        0x11,
        0xce,
        0x1a,
        0x0d,
      ]);

      var wavFile = WavFile();
      expect(wavFile.sampleRate, isNull);
      wavFile.feed(header);
      expect(wavFile.sampleRate, equals(22050));
      expect(wavFile.bitsPerSample, equals(16));
      expect(wavFile.numChannels, equals(2));
      expect(wavFile.audioFormat, equals(1));

      expect(wavFile.done, isTrue);
      expect(wavFile.soundBuffers!.length, equals(2));

      var sb = wavFile.soundBuffers![0];
      expect(sb[0], equals(0.0));
      expect(sb[1], closeTo(0.1804, 0.001));
      sb = wavFile.soundBuffers![1];
      expect(sb[0], equals(0.0));
      expect(sb[1], closeTo(-0.1006, 0.001));
    });

    //    test('read file basic', () {
    //      File file = new File('../../../../../hg/assets/sound/guitar/d_pick.wav');
    //      WavFile wavFile = new WavFile();
    //      return wavFile.read(file.openRead()).then((WavFile wavFile) {
    //        expect(wavFile.soundBuffers[0].length, equals(215424));
    //
    //      });
    //    });
  });
}
