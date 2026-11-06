import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:test/test.dart';

const _rate = 44100;

void main() {
  group('hps', () {
    const algorithm = HpsPitchAlgorithm();

    PitchEstimate? detect(double frequency) => algorithm.analyze(
      PitchFrame(
        PitchSignal.tone(
          frequency,
          seconds: 0.2,
          harmonics: const [1, 0.5, 0.3, 0.15],
        ),
        sampleRate: _rate,
      ),
    );

    test('tones with harmonics', () {
      for (var frequency in [110.0, 196.0, 440.0]) {
        var estimate = detect(frequency)!;
        expect(estimate.frequency, closeTo(frequency, 5));
        expect(estimate.clarity, greaterThan(0.9));
      }
    });

    test('clarity: the harmonicity, low on noise; silence', () {
      var noise = algorithm.analyze(
        PitchFrame(PitchSignal.noise(4096, amplitude: 0.3), sampleRate: _rate),
      );
      expect(noise!.clarity, lessThan(0.4));
      expect(
        algorithm.analyze(
          PitchFrame(PitchSignal.sine(440, amplitude: 0), sampleRate: _rate),
        ),
        isNull,
      );
    });
  });
}
