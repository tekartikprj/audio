import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:test/test.dart';

const _rate = 44100;

/// The guitar strings in standard tuning, Hz.
const _strings = [82.41, 110.00, 146.83, 196.00, 246.94, 329.63];

/// The first [size] samples of [signal] (the attack of the strings).
PitchFrame _start(Float32List signal, int size) =>
    PitchFrame(Float32List.sublistView(signal, 0, size), sampleRate: _rate);

Float32List _chord(List<double> cents) => PitchSignal.mix([
  for (var (index, frequency) in _strings.indexed)
    PitchSignal.pluck(frequency, cents: cents[index]),
], amplitude: 0.8);

void main() {
  group('harmonic peeling', () {
    test('one string', () {
      var estimates = const HarmonicPeelingPitchAlgorithm(
        maxPitches: 1,
      ).analyze(_start(PitchSignal.pluck(440), 16384))!.estimates;
      expect(estimates, hasLength(1));
      expect(estimates.single.frequency, closeTo(440, 1));
      expect(estimates.single.note(), 69);
    });

    test('the six strings of a guitar, in tune and out of tune', () {
      const algorithm = HarmonicPeelingPitchAlgorithm(fftSize: 32768);
      var estimates = algorithm
          .analyze(_start(_chord(List.filled(6, 0)), 32768))!
          .estimates;
      expect(estimates, hasLength(6));
      for (var (index, estimate) in estimates.indexed) {
        expect(
          estimate.frequency,
          closeTo(_strings[index], _strings[index] * 0.02),
        );
      }
      const detune = [-18.0, 10.0, -12.0, 22.0, -8.0, 17.0];
      estimates = algorithm.analyze(_start(_chord(detune), 32768))!.estimates;
      expect(estimates, hasLength(6));
      for (var (index, estimate) in estimates.indexed) {
        var expected = pitchFrequency(
          pitchOfFrequency(_strings[index]),
          cents: detune[index],
        );
        expect(estimate.frequency, closeTo(expected, expected * 0.02));
      }
    });

    test('silence', () {
      expect(
        const HarmonicPeelingPitchAlgorithm().analyze(
          PitchFrame(Float32List(16384), sampleRate: _rate),
        ),
        isNull,
      );
    });
  });
}
