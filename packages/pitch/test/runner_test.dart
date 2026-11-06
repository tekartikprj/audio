import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:test/test.dart';

const _rate = 44100;

/// [samples] given in chunks of [size].
List<PitchStep> _feed(PitchRunner runner, Float32List samples, int size) => [
  for (var start = 0; start < samples.length; start += size)
    ...runner.add(
      Float32List.sublistView(
        samples,
        start,
        math.min(start + size, samples.length),
      ),
    ),
];

PitchRunner _tuner({bool timed = false}) => PitchRunner(
  sampleRate: _rate,
  timed: timed,
  analyses: const [
    PitchAnalysis('yin', YinPitchAlgorithm()),
    PitchAnalysis('hps', HpsPitchAlgorithm()),
    PitchAnalysis('hearing', HearingPitchAlgorithm()),
    PitchAnalysis('reeds', ReedsPitchAlgorithm(source: 'yin')),
  ],
);

void main() {
  group('runner', () {
    test('several algorithms on a musette, chunk by chunk', () {
      var runner = _tuner(timed: true);
      expect(runner.windowSize, 65536);
      var samples = PitchSignal.reeds(pitchFrequency(57), [-19.6, 0, 19.6]);
      var steps = _feed(runner, samples, 1000);
      expect(steps, hasLength(samples.length ~/ 2048));
      expect(runner.received, samples.length);
      var last = steps.last;
      // At the end of the chunk crossing the hop.
      expect(last.sample, 70000);
      expect(last.time, closeTo(last.sample / _rate, 1e-9));
      expect(last.level, greaterThan(0.05));
      expect(last.result<PitchEstimate>('yin')!.note(), 57);
      expect(last.result<PitchEstimate>('hps')!.note(), 57);
      expect(last.result<PitchShares>('hearing')!.hears(57), isTrue);
      var reeds = last.result<PitchReeds>('reeds')!;
      expect(reeds.reeds.map((reed) => reed.cents.round()), [-20, 0, 20]);
      expect(last.result<PitchReeds>('yin'), isNull);
      expect(last.micros!.keys, ['yin', 'hps', 'hearing', 'reeds']);
      // Not timed.
      expect(_feed(_tuner(), samples, 4096).last.micros, isNull);
    });

    test('late: one step for a long chunk', () {
      var runner = _tuner();
      var steps = runner.add(PitchSignal.reeds(440, [0], seconds: 0.5));
      expect(steps, hasLength(1));
      expect(steps.single.sample, 22050);
      // The next step at the next multiple of the hop: 22528.
      expect(runner.add(Float32List(400)), isEmpty);
      expect(runner.add(Float32List(100)), hasLength(1));
      runner.reset();
      expect(runner.received, 0);
    });

    test('A4 at 442, the analyses replaced', () {
      var runner = _tuner();
      var samples = PitchSignal.reeds(440, [-15, 0, 15]);
      var cents = _feed(runner, samples, 4096).last
          .result<PitchReeds>('reeds')!
          .reeds
          .map((reed) => reed.cents.round());
      expect(cents, [-15, 0, 15]);
      runner
        ..reset()
        ..setA4(442);
      expect(
        _feed(runner, samples, 4096).last
            .result<PitchReeds>('reeds')!
            .reeds
            .map((reed) => reed.cents.round()),
        [-23, -8, 7],
      );
      var small = PitchRunner(
        sampleRate: _rate,
        analyses: const [PitchAnalysis('yin', YinPitchAlgorithm())],
      );
      _feed(small, PitchSignal.sine(440, seconds: 0.1), 1024);
      small.analyses = const [
        PitchAnalysis('peeling', HarmonicPeelingPitchAlgorithm()),
      ];
      expect(small.windowSize, 16384);
      expect(small.analyses.single.id, 'peeling');
    });

    test('json: the settings, the steps', () {
      var runner = _tuner();
      var copy = PitchRunner.fromJson(
        (jsonDecode(jsonEncode(runner.toJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(copy.toJson(), runner.toJson());
      var step = _feed(
        runner,
        PitchSignal.reeds(440, [-19.6, 0, 19.6]),
        4096,
      ).last;
      var json = jsonEncode(step.toJson());
      var decoded = PitchStep.fromJson(
        (jsonDecode(json) as Map).cast<String, Object?>(),
      );
      expect(jsonEncode(decoded.toJson()), json);
      expect(decoded.result<PitchReeds>('reeds')!.reeds, hasLength(3));
    });

    test('a stream of chunks', () async {
      var runner = PitchRunner(
        sampleRate: _rate,
        hop: 1024,
        analyses: const [
          PitchAnalysis('yin', YinPitchAlgorithm()),
          PitchAnalysis('chord', HarmonicPeelingPitchAlgorithm()),
        ],
      );
      var strings = PitchTuning.byId('guitar_standard')!.frequencies();
      var chord = PitchSignal.mix([
        for (var frequency in strings) PitchSignal.pluck(frequency),
      ], amplitude: 0.8);
      var chunks = Stream.fromIterable([
        for (var start = 0; start < 44100; start += 500)
          Float32List.sublistView(chord, start, math.min(start + 500, 44100)),
      ]);
      var steps = await runner.bind(chunks).toList();
      expect(steps, hasLength(44100 ~/ 1024));
      var found = steps.any((step) {
        var estimates = step.result<PitchEstimates>('chord')?.estimates;
        if (estimates == null || estimates.length != 6) {
          return false;
        }
        for (var (index, estimate) in estimates.indexed) {
          if ((estimate.frequency - strings[index]).abs() >
              strings[index] * 0.03) {
            return false;
          }
        }
        return true;
      });
      expect(found, isTrue);
    });

    test('quality: level, peak, clipping, windows, when heard', () {
      var runner = _tuner();
      var loud = PitchSignal.reeds(440, [0], amplitude: 1);
      var step = _feed(runner, loud, 4096).last;
      expect(step.peak, closeTo(1, 0.01));
      expect(step.clipped(), isTrue);
      expect(step.decibels, inExclusiveRange(-12.0, 0.0));
      expect(step.windows, {
        'yin': 2048,
        'hps': 4096,
        'hearing': 8192,
        'reeds': 65536,
      });
      expect(step.heardAt('yin'), closeTo(step.time - 1024 / _rate, 1e-9));
      expect(step.heardAt('none'), step.time);
      runner.reset();
      var quiet = _feed(
        runner,
        PitchSignal.reeds(440, [0], amplitude: 0.1),
        4096,
      ).last;
      expect(quiet.clipped(), isFalse);
      expect(quiet.decibels, lessThan(step.decibels - 15));
      var copy = PitchStep.fromJson(
        (jsonDecode(jsonEncode(quiet.toJson())) as Map).cast<String, Object?>(),
      );
      expect(copy.peak, quiet.peak);
      expect(copy.windows, quiet.windows);
    });
  });
}
