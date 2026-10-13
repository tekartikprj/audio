import 'dart:typed_data';

import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file.dart';
import 'package:tekartik_wav/wav_file_fs.dart';
import 'package:test/test.dart';

/// Pcm 16 values of a mono wav written by [writeWavBytes] (44 bytes header).
List<int> _pcmInts(Uint8List bytes) {
  var bd = ByteData.sublistView(bytes);
  return [
    for (var o = 44; o < bytes.length; o += 2) bd.getInt16(o, Endian.little),
  ];
}

/// A mono 8000 Hz wav with exactly [ints] as samples.
Uint8List _wavFromInts(List<int> ints) {
  var bytes = writeWavBytes(
    sampleRate: 8000,
    numChannels: 1,
    soundBuffers: [SoundBuffer(8000, ints.length)],
  );
  var bd = ByteData.sublistView(bytes);
  for (var i = 0; i < ints.length; i++) {
    bd.setInt16(44 + 2 * i, ints[i], Endian.little);
  }
  return bytes;
}

void main() {
  var ints = [-32768, -20000, -1, 0, 1, 16384, 20000, 32767];
  group('wav regression', () {
    test('read format error is reported', () async {
      var bytes = Uint8List.fromList(List.generate(64, (i) => i));
      await expectLater(
        WavFile().read(Stream.value(bytes)),
        throwsA(isA<FormatException>()),
      );
    });
    test('read then write keeps the samples', () async {
      var wav = await WavFile().read(Stream.value(_wavFromInts(ints)));
      var bytes = writeWavBytes(
        sampleRate: 8000,
        numChannels: 1,
        soundBuffers: wav.soundBuffers!,
      );
      expect(_pcmInts(bytes), ints);
    });
    test('pcm16 sound buffer round trip', () {
      var pcm = Pcm16SoundBuffer.fromData(8000, Int16List.fromList(ints));
      var back = Pcm16SoundBuffer.fromSoundBuffer(pcm.toSoundBuffer());
      // -32768 is clamped to -1.0, i.e. -32767
      expect(back.data, [-32767, ...ints.sublist(1)]);
    });
    test('nested views', () {
      var base = SoundBuffer(8000, 30);
      for (var i = 0; i < 30; i++) {
        base[i] = i.toDouble();
      }
      var view = SoundBuffer.view(SoundBuffer.view(base, 10, 20), 5, 5);
      expect(view[0], 15);

      var pcmBase = Pcm16SoundBuffer(8000, 30);
      for (var i = 0; i < 30; i++) {
        pcmBase[i] = i;
      }
      var pcmView = Pcm16SoundBuffer.view(
        Pcm16SoundBuffer.view(pcmBase, 10, 20),
        5,
        5,
      );
      expect(pcmView[0], 15);
    });
    test('unknown chunks before data are skipped', () async {
      var src = _wavFromInts(ints);
      // LIST chunk (even size) then an odd sized chunk with its padding byte
      var list = [0x4c, 0x49, 0x53, 0x54, 4, 0, 0, 0, 0x49, 0x4e, 0x46, 0x4f];
      var odd = [0x66, 0x61, 0x63, 0x74, 3, 0, 0, 0, 1, 2, 3, 0];
      var bytes = Uint8List.fromList([
        ...src.sublist(0, 36),
        ...list,
        ...odd,
        ...src.sublist(36),
      ]);
      ByteData.sublistView(bytes).setUint32(4, bytes.length - 8, Endian.little);
      // Fed one byte at a time to test every split
      var wav = await WavFile().read(
        Stream.fromIterable(bytes.map((byte) => [byte])),
      );
      var out = writeWavBytes(
        sampleRate: 8000,
        numChannels: 1,
        soundBuffers: wav.soundBuffers!,
      );
      expect(_pcmInts(out), ints);
    });
  });
}
