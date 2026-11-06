import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:test/test.dart';

void main() {
  group('frame', () {
    test('level', () {
      expect(pitchLevel(Float32List(0)), 0);
      expect(
        pitchLevel(PitchSignal.sine(440, amplitude: 1)),
        closeTo(0.7071, 0.001),
      );
    });

    test('latest samples', () {
      var frame = PitchFrame(
        Float32List.fromList([1, 2, 3, 4]),
        sampleRate: 8000,
      );
      expect(frame.length, 4);
      expect(frame.latest(2), [3, 4]);
      expect(frame.latest(6), [0, 0, 1, 2, 3, 4]);
      expect(frame.level(1), 4);
    });

    test('spectrum, shared', () {
      var frame = PitchFrame(
        PitchSignal.sine(1000, sampleRate: 8000),
        sampleRate: 8000,
      );
      var spectrum = frame.spectrum(1024);
      expect(identical(spectrum, frame.spectrum(1024)), isTrue);
      expect(spectrum.binHertz, 8000 / 1024);
      expect(spectrum.magnitudes.length, 513);
      var peak = 0;
      for (var i = 1; i < spectrum.magnitudes.length; i++) {
        if (spectrum.magnitudes[i] > spectrum.magnitudes[peak]) {
          peak = i;
        }
      }
      expect(peak * spectrum.binHertz, closeTo(1000, spectrum.binHertz));
      expect(
        spectrum.energyAround(1000, 30),
        greaterThan(0.99 * spectrum.energyBetween(0, 4000)),
      );
      expect(spectrum.level, closeTo(0.3 * 0.7071, 0.001));
    });

    test('peak, decibels, harmonicity', () {
      expect(
        pitchPeak(PitchSignal.sine(440, amplitude: 0.5)),
        closeTo(0.5, 1e-3),
      );
      expect(pitchPeak(Float32List(0)), 0);
      expect(pitchDecibels(1), 0);
      expect(pitchDecibels(0.1), closeTo(-20, 1e-9));
      expect(pitchDecibels(0), double.negativeInfinity);
      var tone = PitchFrame(
        PitchSignal.tone(220),
        sampleRate: 44100,
      ).spectrum(8192);
      expect(tone.harmonicity(220), greaterThan(0.95));
      expect(tone.harmonicity(310), lessThan(0.3));
      expect(tone.harmonicity(0), 0);
      var noisy = PitchFrame(
        PitchSignal.withNoise(PitchSignal.tone(220), amplitude: 0.3),
        sampleRate: 44100,
      ).spectrum(8192);
      expect(noisy.harmonicity(220), inExclusiveRange(0.1, 0.95));
      var noise = PitchFrame(
        PitchSignal.noise(8192, amplitude: 0.3),
        sampleRate: 44100,
      ).spectrum(8192);
      expect(noise.harmonicity(220), lessThan(0.2));
    });
  });
}
