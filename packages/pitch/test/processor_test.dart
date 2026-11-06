import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:test/test.dart';

void main() {
  group('processor', () {
    test('local: chunks in, steps out, analyses replaced', () async {
      expect(PitchProcessor.local.offThread, isFalse);
      var session = await PitchProcessor.local.open(
        PitchRunner(
          sampleRate: 44100,
          analyses: const [
            PitchAnalysis('yin', YinPitchAlgorithm()),
            PitchAnalysis('reeds', ReedsPitchAlgorithm(source: 'yin')),
          ],
        ),
      );
      var steps = <PitchStep>[];
      var done = session.steps.forEach(steps.add);
      var samples = PitchSignal.reeds(440, [-19.6, 0, 19.6]);
      for (var start = 0; start < samples.length; start += 4096) {
        session.add(
          Float32List.sublistView(
            samples,
            start,
            math.min(start + 4096, samples.length),
          ),
        );
      }
      expect(steps, hasLength(samples.length ~/ 2048));
      expect(steps.last.result<PitchReeds>('reeds')!.reeds, hasLength(3));
      session.setAnalyses(const [PitchAnalysis('yin', YinPitchAlgorithm())]);
      session.add(Float32List(2048));
      expect(steps.last.results.keys, ['yin']);
      await session.close();
      await done;
      // Closed: ignored.
      session.add(Float32List(4096));
    });
  });
}
