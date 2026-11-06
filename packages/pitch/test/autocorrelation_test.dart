import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:test/test.dart';

const _rate = 44100;

void main() {
  group('autocorrelation', () {
    const algorithm = AutocorrelationPitchAlgorithm();

    PitchEstimate? detect(double frequency) => algorithm.analyze(
      PitchFrame(
        PitchSignal.sine(frequency, seconds: 0.1, amplitude: 1),
        sampleRate: _rate,
      ),
    );

    test('sines', () {
      for (var frequency in [220.0, 329.63, 440.0]) {
        var estimate = detect(frequency)!;
        expect(estimate.frequency, closeTo(frequency, frequency * 0.005));
        expect(estimate.clarity, inInclusiveRange(0.0, 1.0));
      }
    });

    test('a low string, past the central lobe', () {
      var estimate = algorithm.analyze(
        PitchFrame(PitchSignal.pluck(82.41, seconds: 0.2), sampleRate: _rate),
      )!;
      expect(estimate.frequency, closeTo(82.41, 82.41 * 0.01));
    });

    test('silence, noise', () {
      expect(
        algorithm.analyze(
          PitchFrame(PitchSignal.sine(440, amplitude: 0), sampleRate: _rate),
        ),
        isNull,
      );
      expect(
        algorithm.analyze(
          PitchFrame(
            PitchSignal.noise(4096, amplitude: 0.3),
            sampleRate: _rate,
          ),
        ),
        isNull,
      );
    });
  });
}
