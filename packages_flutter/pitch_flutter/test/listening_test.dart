import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:tekartik_pitch_flutter/pitch_flutter.dart';

class _DeniedInput implements AudioInput {
  @override
  int get sampleRate => 44100;

  @override
  double get latency => 0;

  @override
  Future<Stream<Float32List>> start() async => throw const AudioInputDenied();

  @override
  Future<void> stop() async {}
}

const _analyses = [
  PitchAnalysis('yin', YinPitchAlgorithm()),
  PitchAnalysis('reeds', ReedsPitchAlgorithm(source: 'yin')),
];

Future<void> _push(AudioInputPush input, Float32List samples) async {
  for (var start = 0; start < samples.length; start += 4096) {
    var end = start + 4096 < samples.length ? start + 4096 : samples.length;
    input.push(Float32List.sublistView(samples, start, end));
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('listening', () {
    test('a musette heard, steps, A4, stopped', () async {
      var input = AudioInputPush(latency: 0.1);
      var listening = PitchListening(input, analyses: _analyses);
      var steps = <PitchStep>[];
      listening.onStep = steps.add;
      expect(listening.state.value, AudioInputState.off);
      await listening.start();
      expect(listening.isOn, isTrue);
      var musette = PitchSignal.reeds(440, [-19.6, 0, 19.6]);
      await _push(input, musette);
      expect(steps, hasLength(musette.length ~/ 2048));
      expect(steps.last.sample, steps.length * 2048);
      var last = listening.step.value!;
      expect(identical(last, steps.last), isTrue);
      // The level, at each chunk.
      expect(listening.level.value.quiet(), isFalse);
      expect(listening.level.value.heldPeak, closeTo(0.3, 0.01));
      expect(
        last
            .result<PitchReeds>('reeds')!
            .reeds
            .map((reed) => reed.cents.round()),
        [-20, 0, 20],
      );
      expect(listening.ago(last, 'yin'), closeTo(0.1 + 1024 / 44100, 1e-9));
      // A4 at 442 at once.
      listening.a4 = 442;
      expect(listening.a4, 442);
      await _push(input, musette);
      expect(
        listening.step.value!
            .result<PitchReeds>('reeds')!
            .reeds
            .map((reed) => reed.cents.round()),
        [-27, -8, 12],
      );
      expect(listening.analyses, hasLength(2));
      await listening.stop();
      expect(listening.state.value, AudioInputState.off);
      expect(listening.step.value, isNull);
      expect(listening.level.value, AudioLevel.silence);
      expect(input.started, isFalse);
      await listening.dispose();
    });

    test('denied, no input', () async {
      var denied = PitchListening(_DeniedInput(), analyses: _analyses);
      await denied.start();
      expect(denied.state.value, AudioInputState.denied);
      expect(denied.error, isA<AudioInputDenied>());
      var none = PitchListening(null, analyses: _analyses);
      await none.start();
      expect(none.state.value, AudioInputState.failed);
      expect(none.latency, 0);
    });
  });
}
