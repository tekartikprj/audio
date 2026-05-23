library;

import 'package:tekartik_wav/sound_utils.dart';
import 'package:test/test.dart';

void main() {
  group('sound buffer', () {
    test('view', () {
      var sb = SoundBuffer(1024, 100);
      sb.data.fillRange(0, 10, 1.0);

      sb = SoundBuffer.view(sb, 8, 4);
      expect(sb.sampleRate, equals(1024));
      expect(sb.length, equals(4));
      expect(sb[0], equals(1.0));
      expect(sb[1], equals(1.0));
      expect(sb[2], equals(0.0));
      expect(sb[3], equals(0.0));
    });
  });

  group('Pcm16SoundBuffer mixing', () {
    late Pcm16SoundBuffer b1;
    late Pcm16SoundBuffer b2;
    late Pcm16SoundBuffer b3;

    setUp(() {
      b1 = Pcm16SoundBuffer(44100, 3);
      b1[0] = 10000;
      b1[1] = -10000;
      b1[2] = 0;

      b2 = Pcm16SoundBuffer(44100, 3);
      b2[0] = 20000;
      b2[1] = -20000;
      b2[2] = 32767;

      b3 = Pcm16SoundBuffer(44100, 3);
      b3[0] = 15000;
      b3[1] = -15000;
      b3[2] = -32768;
    });

    test('validation', () {
      expect(() => Pcm16SoundBuffer.mixClamped([]), throwsArgumentError);

      var diffRate = Pcm16SoundBuffer(22050, 3);
      expect(
        () => Pcm16SoundBuffer.mixClamped([b1, diffRate]),
        throwsArgumentError,
      );
    });

    test('mixClamped', () {
      // Sums:
      // index 0: 10000 + 20000 + 15000 = 45000 -> clamped to 32767
      // index 1: -10000 + -20000 + -15000 = -45000 -> clamped to -32768
      // index 2: 0 + 32767 + -32768 = -1 -> -1
      var mixed = Pcm16SoundBuffer.mixClamped([b1, b2, b3]);
      expect(mixed.sampleRate, equals(44100));
      expect(mixed.length, equals(3));
      expect(mixed[0], equals(32767));
      expect(mixed[1], equals(-32768));
      expect(mixed[2], equals(-1));
    });

    test('mixAverage', () {
      // Averages:
      // index 0: (10000 + 20000 + 15000) / 3 = 15000
      // index 1: (-10000 + -20000 + -15000) / 3 = -15000
      // index 2: (0 + 32767 + -32768) / 3 = -0.33 -> 0
      var mixed = Pcm16SoundBuffer.mixAverage([b1, b2, b3]);
      expect(mixed[0], equals(15000));
      expect(mixed[1], equals(-15000));
      expect(mixed[2], equals(0));
    });

    test('mixSoftClipped', () {
      // Mixes two max boundaries to verify no clipping and soft compression:
      var max1 = Pcm16SoundBuffer(44100, 1)..[0] = 32767;
      var max2 = Pcm16SoundBuffer(44100, 1)..[0] = 32767;
      var mixedMax = Pcm16SoundBuffer.mixSoftClipped([max1, max2]);
      expect(mixedMax[0], equals(32767));

      var min1 = Pcm16SoundBuffer(44100, 1)..[0] = -32768;
      var min2 = Pcm16SoundBuffer(44100, 1)..[0] = -32768;
      var mixedMin = Pcm16SoundBuffer.mixSoftClipped([min1, min2]);
      expect(mixedMin[0], equals(-32768));

      // Sequential mix of b1, b2, b3
      // Step 1: b1 [10000, -10000, 0]
      // Step 2: mix with b2 [20000, -20000, 32767]
      //   idx 0: both positive -> 10000 + 20000 - (10000 * 20000) / 32767 = 30000 - 6103.7 = 23896
      //   idx 1: both negative -> -10000 + -20000 - (-10000 * -20000) / -32768 = -30000 - (-6103.5) = -23896
      //   idx 2: zero & positive -> 0 + 32767 - (0) = 32767
      // Step 3: mix with b3 [15000, -15000, -32768]
      //   idx 0: both positive -> 23896 + 15000 - (23896 * 15000) / 32767 = 38896 - 10939.0 = 27957
      //   idx 1: both negative -> -23896 + -15000 - (-23896 * -15000) / -32768 = -38896 - (-10938.7) = -27957
      //   idx 2: positive & negative -> 32767 + -32768 = -1
      var mixed = Pcm16SoundBuffer.mixSoftClipped([b1, b2, b3]);
      expect(mixed[0], closeTo(27957, 2));
      expect(mixed[1], closeTo(-27957, 2));
      expect(mixed[2], equals(-1));
    });

    test('mixNormalized', () {
      // Sums: [45000, -45000, -1]
      // peak: 45000.0 > 32767.0
      // scale = 32767.0 / 45000.0 = 0.7281555...
      // index 0: 45000 * scale = 32767
      // index 1: -45000 * scale = -32767
      // index 2: -1 * scale = -0.728... -> -1
      var mixed = Pcm16SoundBuffer.mixNormalized([b1, b2, b3]);
      expect(mixed[0], equals(32767));
      expect(mixed[1], equals(-32767));
      expect(mixed[2], equals(-1));

      // If sum does not exceed, keep original
      var low1 = Pcm16SoundBuffer(44100, 2)
        ..[0] = 5000
        ..[1] = -5000;
      var low2 = Pcm16SoundBuffer(44100, 2)
        ..[0] = 10000
        ..[1] = -10000;
      var mixedLow = Pcm16SoundBuffer.mixNormalized([low1, low2]);
      expect(mixedLow[0], equals(15000));
      expect(mixedLow[1], equals(-15000));
    });

    test('different lengths', () {
      var short = Pcm16SoundBuffer(44100, 1)..[0] = 10000;
      var long = Pcm16SoundBuffer(44100, 3)
        ..[0] = 20000
        ..[1] = 15000
        ..[2] = -5000;

      // clamped:
      // index 0: 10000 + 20000 = 30000
      // index 1: 15000
      // index 2: -5000
      var mixedClamped = Pcm16SoundBuffer.mixClamped([short, long]);
      expect(mixedClamped.length, equals(3));
      expect(mixedClamped[0], equals(30000));
      expect(mixedClamped[1], equals(15000));
      expect(mixedClamped[2], equals(-5000));

      // average (total count is 2):
      // index 0: (10000 + 20000) / 2 = 15000
      // index 1: 15000 / 2 = 7500
      // index 2: -5000 / 2 = -2500
      var mixedAverage = Pcm16SoundBuffer.mixAverage([short, long]);
      expect(mixedAverage[0], equals(15000));
      expect(mixedAverage[1], equals(7500));
      expect(mixedAverage[2], equals(-2500));

      // soft-clipped:
      // result initialized to [0, 0, 0]
      // mix short: [10000, 0, 0]
      // mix long:
      // index 0: mix(10000, 20000) = 10000 + 20000 - (10000 * 20000)/32767 = 23896
      // index 1: mix(0, 15000) = 15000
      // index 2: mix(0, -5000) = -5000
      var mixedSoft = Pcm16SoundBuffer.mixSoftClipped([short, long]);
      expect(mixedSoft[0], closeTo(23896, 2));
      expect(mixedSoft[1], equals(15000));
      expect(mixedSoft[2], equals(-5000));

      // normalized:
      // sums: [30000, 15000, -5000]
      // peak: 30000 <= 32767 -> no scaling
      var mixedNorm = Pcm16SoundBuffer.mixNormalized([short, long]);
      expect(mixedNorm[0], equals(30000));
      expect(mixedNorm[1], equals(15000));
      expect(mixedNorm[2], equals(-5000));
    });
  });
}
