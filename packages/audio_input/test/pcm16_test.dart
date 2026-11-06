import 'dart:typed_data';

import 'package:tekartik_audio_input/audio_input.dart';
import 'package:test/test.dart';

void main() {
  group('pcm16', () {
    test('little endian, a byte carried to the next chunk', () {
      var decoder = AudioInputPcm16Decoder();
      // 16384 (0.5), -32768 (-1), then 0x7fff split across chunks.
      expect(
        decoder.convert(Uint8List.fromList([0x00, 0x40, 0x00, 0x80, 0xff])),
        [0.5, -1],
      );
      var next = decoder.convert(Uint8List.fromList([0x7f]));
      expect(next.single, closeTo(32767 / 32768, 1e-9));
      expect(decoder.convert(Uint8List.fromList([0x01])), isEmpty);
      decoder.reset();
      expect(decoder.convert(Uint8List.fromList([0x00, 0x00])), [0]);
    });
  });
}
