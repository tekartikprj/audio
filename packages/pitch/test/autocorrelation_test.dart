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

    test('sines, to 2 cents', () {
      // The refinement between the samples moves towards the higher
      // neighbor: the other way round was up to 11 cents off.
      for (var frequency in [220.0, 329.63, 440.0, 587.33, 880.0, 1046.5]) {
        var estimate = detect(frequency)!;
        expect(
          pitchCents(frequency, estimate.frequency).abs(),
          lessThan(2),
          reason: '$frequency Hz',
        );
        expect(estimate.clarity, inInclusiveRange(0.0, 1.0));
      }
    });

    test('a low string, past the central lobe', () {
      var estimate = algorithm.analyze(
        PitchFrame(PitchSignal.pluck(82.41, seconds: 0.2), sampleRate: _rate),
      )!;
      expect(pitchCents(82.41, estimate.frequency).abs(), lessThan(6));
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
