import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:test/test.dart';

const _rate = 44100;

PitchEstimate? _detect(Float32List samples) =>
    const YinPitchAlgorithm().analyze(PitchFrame(samples, sampleRate: _rate));

void main() {
  group('yin', () {
    test('sines', () {
      for (var frequency in [55.0, 82.41, 174.61, 440.0, 445.5, 1760.0]) {
        var estimate = _detect(PitchSignal.sine(frequency, seconds: 0.2))!;
        expect(estimate.frequency, closeTo(frequency, frequency * 0.0006));
        expect(estimate.clarity, greaterThan(0.9));
      }
      var sharp = _detect(
        PitchSignal.sine(pitchFrequency(69, cents: 8), seconds: 0.2),
      )!;
      expect(sharp.pitch(), closeTo(69.08, 0.01));
      expect(sharp.cents(), closeTo(8, 1));
      expect(sharp.note(), 69);
      expect(sharp.pitch(a4: 442), closeTo(69.08 - 0.0785, 0.01));
    });

    test('a tone with harmonics, a long buffer', () {
      for (var frequency in [220.0, 261.63, 440.0]) {
        var estimate = _detect(
          PitchSignal.tone(
            frequency,
            seconds: 0.2,
            harmonics: const [1, 0.5, 0.3, 0.15],
          ),
        )!;
        expect(estimate.frequency, closeTo(frequency, frequency * 0.001));
      }
    });

    test('silence, noise', () {
      expect(_detect(Float32List(8192)), isNull);
      expect(_detect(PitchSignal.noise(8192, amplitude: 0.3)), isNull);
    });

    test('reeds heard as their middle one', () {
      var registers = {
        'clarinet': [0.0],
        'violin': [0.0, 9.0],
        'musette': [-19.6, 0.0, 19.6],
      };
      for (var MapEntry(key: name, value: cents) in registers.entries) {
        var estimate = _detect(PitchSignal.reeds(440, cents, seconds: 0.5))!;
        expect(
          estimate.pitch(),
          closeTo(69 + cents.reduce((a, b) => a + b) / cents.length / 100, 0.1),
          reason: name,
        );
      }
      // 16' + 8' + 8' sharp + 4': heard at the low reed.
      var master = PitchSignal.mix([
        PitchSignal.tone(220, seconds: 0.5),
        PitchSignal.tone(440, seconds: 0.5),
        PitchSignal.tone(440, cents: 12, seconds: 0.5, phase: 1),
        PitchSignal.tone(880, seconds: 0.5),
      ]);
      expect(_detect(master)!.pitch(), closeTo(57, 0.15));
    });

    test('window', () {
      expect(const YinPitchAlgorithm().windowSize(44100), 2048);
      expect(const YinPitchAlgorithm(minFrequency: 25).windowSize(44100), 4096);
      expect(const YinPitchAlgorithm().windowSize(8000), 512);
    });
  });
}
