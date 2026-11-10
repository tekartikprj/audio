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
    test('chunks before the fmt chunk are skipped', () async {
      var src = _wavFromInts(ints);
      // JUNK (padding of field recorders) then an odd sized bext chunk with
      // its padding byte, before 'fmt '
      var junk = [0x4a, 0x55, 0x4e, 0x4b, 4, 0, 0, 0, 0, 0, 0, 0];
      var bext = [0x62, 0x65, 0x78, 0x74, 3, 0, 0, 0, 1, 2, 3, 0];
      var bytes = Uint8List.fromList([
        ...src.sublist(0, 12),
        ...junk,
        ...bext,
        ...src.sublist(12),
      ]);
      ByteData.sublistView(bytes).setUint32(4, bytes.length - 8, Endian.little);
      for (var stream in [
        Stream.value(bytes),
        Stream.fromIterable(bytes.map((byte) => [byte])),
      ]) {
        var wav = await WavFile().read(stream);
        expect(wav.sampleRate, 8000);
        var out = writeWavBytes(
          sampleRate: 8000,
          numChannels: 1,
          soundBuffers: wav.soundBuffers!,
        );
        expect(_pcmInts(out), ints);
      }
    });
    test('a data chunk before the fmt chunk is a format error', () async {
      var src = _wavFromInts(ints);
      var bytes = Uint8List.fromList([
        ...src.sublist(0, 12),
        ...src.sublist(36),
      ]);
      await expectLater(
        WavFile().read(Stream.value(bytes)),
        throwsA(isA<FormatException>()),
      );
    });
    test('a fmt chunk shorter than 16 bytes is a format error', () async {
      for (var size in [0, 2, 15]) {
        var src = _wavFromInts(ints);
        var bytes = Uint8List.fromList([
          ...src.sublist(0, 16),
          size,
          0,
          0,
          0,
          ...src.sublist(20, 20 + size),
          ...src.sublist(36),
        ]);
        await expectLater(
          WavFile().read(Stream.value(bytes)),
          throwsA(isA<FormatException>()),
          reason: 'fmt size $size',
        );
      }
    });
    test('0 channels is a format error', () async {
      var bytes = _wavFromInts(ints);
      ByteData.sublistView(bytes).setUint16(22, 0, Endian.little);
      await expectLater(
        WavFile().read(Stream.value(bytes)),
        throwsA(isA<FormatException>()),
      );
    });
    test('a sample rate of 0 is a format error', () async {
      var bytes = _wavFromInts(ints);
      ByteData.sublistView(bytes).setUint32(24, 0, Endian.little);
      await expectLater(
        WavFile().read(Stream.value(bytes)),
        throwsA(isA<FormatException>()),
      );
    });
    test('a truncated file is a format error', () async {
      var src = _wavFromInts(ints);
      for (var length in [12, 20, 36, 44, src.length - 1]) {
        await expectLater(
          WavFile().read(Stream.value(src.sublist(0, length))),
          throwsA(isA<FormatException>()),
          reason: 'length $length',
        );
      }
      // The header of a recorder that never wrote its sizes
      var bytes = Uint8List.fromList(src);
      ByteData.sublistView(bytes).setUint32(40, 0xFFFFFFFF, Endian.little);
      await expectLater(
        WavFile().read(Stream.value(bytes)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
