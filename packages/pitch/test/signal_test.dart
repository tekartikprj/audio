import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:test/test.dart';

double _peak(Float32List samples) =>
    samples.fold(0.0, (max, sample) => sample.abs() > max ? sample.abs() : max);

void main() {
  group('signal', () {
    test('sine, tone', () {
      var sine = PitchSignal.sine(440, seconds: 0.5, sampleRate: 8000);
      expect(sine, hasLength(4000));
      expect(_peak(sine), closeTo(0.3, 0.001));
      var tone = PitchSignal.tone(110, seconds: 0.1, amplitude: 0.5);
      expect(tone, hasLength(4410));
      expect(_peak(tone), closeTo(0.5, 1e-6));
      // Harmonics above the Nyquist frequency are left out.
      var high = PitchSignal.tone(15000, seconds: 0.1, harmonics: const [1, 1]);
      expect(_peak(high), closeTo(0.3, 1e-6));
      var drifting = PitchSignal.tone(
        440,
        seconds: 0.1,
        driftCentsPerSecond: 10,
        tremolo: 0.5,
      );
      expect(_peak(drifting), lessThanOrEqualTo(0.3 + 1e-6));
    });

    test('pluck decays, reeds, mix, noise', () {
      var pluck = PitchSignal.pluck(220, seconds: 1);
      expect(pluck.first, 0);
      expect(
        pitchLevel(Float32List.sublistView(pluck, 0, 4410)),
        greaterThan(2 * pitchLevel(Float32List.sublistView(pluck, 33075))),
      );
      var reeds = PitchSignal.reeds(440, [-20, 0, 20], seconds: 0.5);
      expect(_peak(reeds), closeTo(0.3, 1e-6));
      var mix = PitchSignal.mix(
        [
          Float32List.fromList([1, 1]),
          Float32List.fromList([1]),
        ],
        gains: [1, 2],
      );
      expect(mix, [3, 1]);
      expect(
        PitchSignal.mix([
          Float32List.fromList([2, -4]),
        ], amplitude: 1),
        [0.5, -1],
      );
      expect(PitchSignal.noise(100), PitchSignal.noise(100));
      expect(_peak(PitchSignal.noise(1000, amplitude: 0.2)), lessThan(0.2));
      expect(PitchSignal.withNoise(Float32List(10)), hasLength(10));
      expect(PitchSignal.reedHarmonics(3), hasLength(3));
    });
  });
}
