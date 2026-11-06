import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tekartik_audio_input/audio_input.dart';
import 'package:test/test.dart';

Float32List _sine(double amplitude, int length) => Float32List.fromList([
  for (var i = 0; i < length; i++)
    amplitude * math.sin(2 * math.pi * 440 * i / 8000),
]);

void main() {
  group('level', () {
    test('decibels', () {
      expect(audioDecibels(1), 0);
      expect(audioDecibels(0.1), closeTo(-20, 1e-9));
      expect(audioDecibels(0), double.negativeInfinity);
      expect(AudioLevel.silence.decibels, double.negativeInfinity);
      expect(AudioLevel.silence.quiet(), isTrue);
    });

    test('rises at once, falls slowly, peaks held, clipping kept', () {
      var meter = AudioLevelMeter(sampleRate: 8000);
      var loud = meter.add(_sine(0.5, 800));
      expect(loud.rms, closeTo(0.5 / math.sqrt2, 0.01));
      expect(loud.peak, closeTo(0.5, 0.01));
      expect(loud.display, loud.rms);
      expect(loud.clipped, isFalse);
      expect(loud.quiet(), isFalse);
      // 0.1 s of silence: the display falls 2.4 dB, the peak is held.
      var after = meter.add(Float32List(800));
      expect(after.rms, 0);
      expect(after.displayDecibels, closeTo(loud.displayDecibels - 2.4, 0.01));
      expect(after.heldPeak, loud.peak);
      // 2 s later: the peak dropped.
      for (var i = 0; i < 20; i++) {
        after = meter.add(Float32List(800));
      }
      expect(after.heldPeak, 0);
      expect(after.quiet(), isTrue);
      // Clipping, kept a second.
      var clipped = meter.add(_sine(1, 800));
      expect(clipped.clipped, isTrue);
      expect(meter.add(Float32List(4000)).clipped, isTrue);
      expect(meter.add(Float32List(4800)).clipped, isFalse);
      meter.reset();
      expect(meter.add(Float32List(10)).display, 0);
      expect(loud.toString(), contains('dB'));
    });

    test('a metered input: the samples through, the levels out', () async {
      var input = AudioInputPush(sampleRate: 8000, latency: 0.1);
      var metered = AudioInputMetered(input);
      expect(metered.sampleRate, 8000);
      expect(metered.latency, 0.1);
      expect(metered.level, AudioLevel.silence);
      var levels = <AudioLevel>[];
      metered.levels.listen(levels.add);
      var chunks = <Float32List>[];
      var subscription = (await metered.start()).listen(chunks.add);
      input
        ..push(_sine(0.5, 800))
        ..push(_sine(0.1, 800));
      await Future<void>.delayed(Duration.zero);
      expect(chunks, hasLength(2));
      expect(levels, hasLength(2));
      expect(levels.first.peak, closeTo(0.5, 0.01));
      expect(metered.level.peak, closeTo(0.1, 0.01));
      // Stopped after the consumer cancelled: no hang, silence.
      await subscription.cancel();
      await metered.stop();
      expect(metered.level, AudioLevel.silence);
      expect(levels.last, AudioLevel.silence);
      await metered.close();
    });
  });
}
