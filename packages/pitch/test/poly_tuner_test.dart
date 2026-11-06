import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:test/test.dart';

const _rate = 44100;

PitchTargets? _tune(Float32List samples, List<double> targets, {int? size}) =>
    PolyTunerPitchAlgorithm(targets: targets, fftSize: size ?? 8192).analyze(
      PitchFrame(
        size == null ? samples : Float32List.sublistView(samples, 0, size),
        sampleRate: _rate,
      ),
    );

void main() {
  group('poly tuner', () {
    test('one result per target, the silent ones low', () {
      var targets = _tune(PitchSignal.sine(440, seconds: 0.2), [
        440,
        329.63,
        246.94,
      ])!.targets;
      expect(targets.map((target) => target.target), [440, 329.63, 246.94]);
      var a4 = targets.first;
      expect(a4.found, isTrue);
      expect(a4.frequency, closeTo(440, 1));
      expect(a4.cents, closeTo(0, 4));
      expect(a4.level, 1);
      expect(a4.clarity, greaterThan(0.9));
      expect(a4.sounds(), isTrue);
      for (var silent in targets.skip(1)) {
        expect(silent.level, lessThan(0.05), reason: '$silent');
        expect(silent.sounds(), isFalse, reason: '$silent');
      }
    });

    test('the strings of a guitar out of tune, each to a few cents', () {
      var tuning = PitchTuning.byId('guitar_standard')!;
      var frequencies = tuning.frequencies();
      const detune = [-18.0, 10.0, -12.0, 22.0, -8.0, 17.0];
      var chord = PitchSignal.mix([
        for (var (index, frequency) in frequencies.indexed)
          PitchSignal.pluck(frequency, cents: detune[index]),
      ], amplitude: 0.8);
      var targets = _tune(chord, frequencies, size: 32768)!.targets;
      expect(targets, hasLength(6));
      for (var (index, target) in targets.indexed) {
        expect(target.cents, closeTo(detune[index], 3), reason: '$target');
        expect(target.sounds(), isTrue, reason: '$target');
      }
    });

    test('noise: no string sounds; silence', () {
      var frequencies = PitchTuning.byId('guitar_standard')!.frequencies();
      var targets = _tune(
        PitchSignal.noise(8192, amplitude: 0.3),
        frequencies,
      )!.targets;
      for (var target in targets) {
        expect(target.clarity, lessThan(0.3), reason: '$target');
        expect(target.sounds(minClarity: 0.5), isFalse, reason: '$target');
      }
      expect(_tune(Float32List(8192), [440]), isNull);
    });
  });
}
