import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:test/test.dart';

void main() {
  group('fft', () {
    test('a cosine at a bin, back again', () {
      var fft = PitchFft(64);
      var re = Float64List.fromList([
        for (var i = 0; i < 64; i++) math.cos(2 * math.pi * 5 * i / 64),
      ]);
      var im = Float64List(64);
      var source = Float64List.fromList(re);
      fft.transform(re, im);
      expect(re[5], closeTo(32, 1e-9));
      expect(re[59], closeTo(32, 1e-9));
      expect(re[4].abs() + im[4].abs(), lessThan(1e-9));
      fft.transform(re, im, inverse: true);
      for (var i = 0; i < 64; i++) {
        expect(re[i], closeTo(source[i], 1e-9));
      }
    });

    test('sizes', () {
      expect(() => PitchFft(100), throwsArgumentError);
      expect(() => PitchFft(1), throwsArgumentError);
      expect(identical(PitchFft(1024), PitchFft(1024)), isTrue);
      expect(PitchFft.isPowerOfTwo(1024), isTrue);
      expect(PitchFft.isPowerOfTwo(1000), isFalse);
      expect(PitchFft.powerOfTwoAtLeast(1000), 1024);
      expect(PitchFft.powerOfTwoAtLeast(1024), 1024);
      expect(PitchFft.powerOfTwoAtLeast(3, minimum: 256), 256);
    });
  });
}
