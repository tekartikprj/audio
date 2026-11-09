import 'dart:math';
import 'dart:typed_data';

import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file.dart';
import 'package:tekartik_wav/wav_file_fs.dart';
import 'package:test/test.dart';

/// A stereo 8000 Hz wav of 8 frames.
Uint8List _wav() {
  var buffers = [
    for (var channel = 0; channel < 2; channel++)
      SoundBuffer(8000, 8)
        ..data.setAll(0, [
          for (var i = 0; i < 8; i++) (i % 7 - 3) / 4 * (channel + 1) / 2,
        ]),
  ];
  return writeWavBytes(sampleRate: 8000, numChannels: 2, soundBuffers: buffers);
}

/// Reads [bytes]: null when read, the error otherwise.
Future<Object?> _read(Uint8List bytes, {bool byteByByte = false}) async {
  try {
    var wav = await WavFile().read(
      byteByByte
          ? Stream.fromIterable(bytes.map((byte) => [byte]))
          : Stream.value(bytes),
    );
    expect(wav.soundBuffers, isNotNull);
    return null;
  } catch (e) {
    return e;
  }
}

/// Bad files: a [FormatException], never another error, an endless loop or
/// a huge allocation.
void main() {
  var timeout = const Timeout(Duration(minutes: 1));
  var wav = _wav();

  test('every truncation is a format error', () async {
    for (var length = 0; length < wav.length; length++) {
      var error = await _read(wav.sublist(0, length));
      expect(error, isA<FormatException>(), reason: 'length $length');
    }
    expect(await _read(wav), isNull);
  }, timeout: timeout);

  test('every byte changed', () async {
    for (var i = 0; i < wav.length; i++) {
      for (var value in [0, 1, 2, 15, 0x7f, 0x80, 0xfe, 0xff]) {
        var bytes = Uint8List.fromList(wav)..[i] = value;
        var error = await _read(bytes);
        if (error != null) {
          expect(error, isA<FormatException>(), reason: 'byte $i = $value');
        }
      }
    }
  }, timeout: timeout);

  test('random changes and tails', () async {
    var random = Random(1);
    for (var n = 0; n < 2000; n++) {
      var bytes = Uint8List.fromList(wav);
      for (var k = 0; k <= random.nextInt(4); k++) {
        bytes[random.nextInt(bytes.length)] = random.nextInt(256);
      }
      var error = await _read(bytes, byteByByte: n % 10 == 0);
      if (error != null) {
        expect(error, isA<FormatException>(), reason: 'mutation $n');
      }
    }
    for (var n = 0; n < 500; n++) {
      var bytes = Uint8List.fromList([
        ...wav.sublist(0, 12),
        for (var i = 0; i < random.nextInt(64); i++) random.nextInt(256),
      ]);
      var error = await _read(bytes);
      if (error != null) {
        expect(error, isA<FormatException>(), reason: 'tail $n');
      }
    }
  }, timeout: timeout);
}
