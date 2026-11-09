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
      // At the multiples of the hop, whatever the chunks.
      expect(last.sample, steps.length * 2048);
      expect(steps[1].sample - steps[0].sample, 2048);
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

    test('chunks of any size; late: only the last steps', () {
      var runner = _tuner();
      // 10 hops in a chunk: the last 4.
      var steps = runner.add(PitchSignal.reeds(440, [0], seconds: 0.5));
      expect(steps.map((step) => step.sample), [14336, 16384, 18432, 20480]);
      // The next step at the next multiple of the hop: 22528.
      expect(runner.add(Float32List(400)), isEmpty);
      expect(runner.add(Float32List(100)).single.sample, 22528);
      // A chunk of two hops: two steps.
      expect(runner.add(Float32List(4096)).map((step) => step.sample), [
        24576,
        26624,
      ]);
      runner.reset();
      expect(runner.received, 0);
      // One step per chunk at most.
      var one = PitchRunner(
        sampleRate: _rate,
        maxBehind: 1,
        analyses: const [PitchAnalysis('yin', YinPitchAlgorithm())],
      );
      expect(one.add(Float32List(22050)).single.sample, 20480);
      expect(one.toJson()['maxBehind'], 1);
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

    test('analyses with a longer window: the samples kept stay in order', () {
      // A ramp: sample i is i + 1, the frame order is visible.
      var next = 0;
      Float32List ramp(int count) => Float32List.fromList([
        for (var i = 0; i < count; i++) (++next).toDouble(),
      ]);
      var runner = PitchRunner(
        sampleRate: _rate,
        analyses: const [PitchAnalysis('spy', _SpyAlgorithm(4096))],
      );
      runner.add(ramp(10000));
      runner.analyses = const [PitchAnalysis('spy', _SpyAlgorithm(16384))];
      expect(runner.received, 10000);
      var step = runner.add(ramp(240)).single;
      expect(step.sample, 10240);
      var frame = step.result<_SpyResult>('spy')!.samples;
      expect(frame, hasLength(16384));
      // Zeros before the first sample kept, then every sample in order up
      // to the last one received: the 6144 kept and the 240 new ones.
      var first = frame.indexWhere((sample) => sample != 0);
      expect(frame.length - first, 6144 + 240);
      for (var i = first; i < frame.length; i++) {
        expect(frame[i], 10240 - (frame.length - 1 - i), reason: 'at $i');
      }
      // A clean note right after the change is still heard.
      var yin = PitchRunner(
        sampleRate: _rate,
        analyses: const [PitchAnalysis('yin', YinPitchAlgorithm())],
      );
      var sine = PitchSignal.sine(440, seconds: 0.5);
      yin.add(Float32List.sublistView(sine, 0, 10000));
      yin.analyses = const [
        PitchAnalysis('yin', YinPitchAlgorithm()),
        PitchAnalysis('peeling', HarmonicPeelingPitchAlgorithm()),
      ];
      var after = yin.add(Float32List.sublistView(sine, 10000, 10240)).single;
      expect(after.result<PitchEstimate>('yin')!.frequency, closeTo(440, 0.5));
      expect(after.level, closeTo(0.3 / math.sqrt2, 0.01));
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

/// The frame an analysis was given.
class _SpyResult extends PitchResult {
  final Float32List samples;

  _SpyResult(this.samples);

  @override
  String get kind => 'spy';

  @override
  Map<String, Object?> toJson() => {'kind': kind};
}

/// Keeps the frame it is given.
class _SpyAlgorithm extends PitchAlgorithm<_SpyResult> {
  final int size;

  const _SpyAlgorithm(this.size);

  @override
  String get type => 'spy';

  @override
  int windowSize(int sampleRate) => size;

  @override
  _SpyResult analyze(PitchFrame frame, {PitchStep? step}) =>
      _SpyResult(Float32List.fromList(frame.latest(size)));

  @override
  Map<String, Object?> toJson() => {'type': type, 'size': size};
}
