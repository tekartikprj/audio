import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:test/test.dart';

const _rate = 44100;

/// The musette detune: the third reed 5 Hz off at A4 (435, 440, 445 Hz).
const _musette = 19.6;

PitchReeds? _analyze(Float32List samples, {double a4 = 440}) =>
    ReedsPitchAlgorithm(a4: a4).analyze(PitchFrame(samples, sampleRate: _rate));

void _expectCents(PitchReeds? reeds, List<double> cents, {String? reason}) {
  expect(reeds, isNotNull, reason: reason);
  expect(reeds!.reeds, hasLength(cents.length), reason: '$reason $reeds');
  for (var (index, reed) in reeds.reeds.indexed) {
    expect(reed.cents, closeTo(cents[index], 0.5), reason: '$reason $reeds');
  }
}

void main() {
  group('reeds', () {
    const algorithm = ReedsPitchAlgorithm();

    test('the window: longer for the low notes', () {
      expect(algorithm.sizeFor(pitchFrequency(69), _rate), 16384);
      expect(algorithm.sizeFor(pitchFrequency(53), _rate), 32768);
      expect(algorithm.sizeFor(pitchFrequency(93), _rate), 16384);
      expect(algorithm.sizeFor(pitchFrequency(45), _rate), 32768);
      expect(algorithm.windowSize(_rate), 65536);
    });

    test('one, two and three reeds, F3 to A6', () {
      for (var pitch in [53, 57, 60, 64, 69, 72, 76, 81, 88, 93]) {
        var name = pitchNoteName(pitch);
        var frequency = pitchFrequency(pitch);
        var single = _analyze(PitchSignal.reeds(frequency, [0]));
        _expectCents(single, [0], reason: 'single $name');
        expect(single!.pitch, pitch);
        expect(single.beats, isEmpty);
        expect(single.spread, 0);
        _expectCents(_analyze(PitchSignal.reeds(frequency, [0, 9])), [
          0,
          9,
        ], reason: 'violin $name');
        var musette = _analyze(
          PitchSignal.reeds(frequency, [-_musette, 0, _musette]),
        );
        _expectCents(musette, [
          -_musette,
          0,
          _musette,
        ], reason: 'musette $name');
        var sharp = frequency * (math.pow(2, _musette / 1200) - 1);
        var flat = frequency * (1 - math.pow(2, -_musette / 1200));
        expect(musette!.beats[0], closeTo(flat, flat * 0.03), reason: name);
        expect(musette.beats[1], closeTo(sharp, sharp * 0.03), reason: name);
        for (var reed in musette.reeds) {
          expect(reed.level, greaterThan(0.8), reason: '$name $musette');
        }
      }
    });

    test('a musette A4: 435, 440, 445 Hz, 5 beats per second', () {
      var reeds = _analyze(PitchSignal.reeds(440, [-_musette, 0, _musette]))!;
      expect(reeds.reeds.map((reed) => reed.frequency.round()), [
        435,
        440,
        445,
      ]);
      expect(reeds.beats[0], closeTo(4.95, 0.1));
      expect(reeds.beats[1], closeTo(5.01, 0.1));
      expect(reeds.outerBeats, closeTo(9.96, 0.15));
      expect(reeds.spread, closeTo(2 * _musette, 0.5));
    });

    test('uneven, a weak reed, noise, two reeds, A4 at 442', () {
      _expectCents(
        _analyze(
          PitchSignal.withNoise(
            PitchSignal.reeds(
              pitchFrequency(67),
              [-14, 3, 24],
              levels: [0.5, 1, 0.8],
            ),
          ),
        ),
        [-14, 3, 24],
      );
      _expectCents(_analyze(PitchSignal.reeds(pitchFrequency(62), [-2, 12])), [
        -2,
        12,
      ]);
      var at442 = PitchSignal.reeds(pitchFrequency(69, a4: 442), [-15, 0, 15]);
      _expectCents(_analyze(at442, a4: 442), [-15, 0, 15]);
      // Heard at 440: 7.85 cents sharp.
      _expectCents(_analyze(at442), [-7.15, 7.85, 22.85]);
    });

    test('the beats under a swell and a drift', () {
      var reeds = _analyze(
        PitchSignal.reeds(
          440,
          [-18, 0, 18],
          tremolo: 0.4,
          driftCentsPerSecond: 3,
        ),
      )!;
      expect(reeds.reeds, hasLength(3));
      expect(reeds.beats[0], closeTo(4.55, 0.05));
      expect(reeds.beats[1], closeTo(4.60, 0.05));
    });

    test('silence, a short window, the frequency from another analysis', () {
      var frame = PitchFrame(Float32List(32768), sampleRate: _rate);
      expect(algorithm.analyze(frame), isNull);
      expect(algorithm.analyzeAt(frame, 440), isNull);
      expect(algorithm.analyzeAt(frame, 0), isNull);
      // Fewer samples than the window: zeros before, still heard.
      var short = Float32List.sublistView(
        PitchSignal.reeds(440, [-_musette, 0, _musette]),
        22050,
        33075,
      );
      expect(
        algorithm.analyzeAt(PitchFrame(short, sampleRate: _rate), 440),
        isNotNull,
      );
      // From the step.
      var sourced = const ReedsPitchAlgorithm(source: 'yin');
      var musette = PitchFrame(
        PitchSignal.reeds(440, [-_musette, 0, _musette]),
        sampleRate: _rate,
      );
      var step = PitchStep(sample: 0, sampleRate: _rate, level: 0.1);
      expect(sourced.analyze(musette, step: step), isNull);
      step.results['yin'] = const PitchEstimate(440, clarity: 0.9);
      _expectCents(sourced.analyze(musette, step: step), [
        -_musette,
        0,
        _musette,
      ]);
      expect(sourced.windowSize(_rate), 65536);
    });

    test('uncertainty and support of each reed', () {
      var clean = _analyze(PitchSignal.reeds(440, [-_musette, 0, _musette]))!;
      for (var reed in clean.reeds) {
        expect(reed.uncertainty, inExclusiveRange(0.0, 0.05), reason: '$reed');
        expect(reed.support, 1);
      }
      expect(clean.uncertainty, lessThan(0.05));
      for (var uncertainty in clean.beatUncertainties) {
        expect(uncertainty, lessThan(0.01));
      }
      var noisy = _analyze(
        PitchSignal.withNoise(
          PitchSignal.reeds(440, [-_musette, 0, _musette]),
          amplitude: 0.05,
        ),
      )!;
      expect(noisy.uncertainty, greaterThan(clean.uncertainty));
      expect(noisy.uncertainty, lessThan(0.5));
    });
  });
}
