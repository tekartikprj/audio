// Finds the notes of a short melody off the main thread: in a web worker in
// a browser (pitch_worker.js next to the page), in an isolate on the VM.
//
//     dart run example/pitch_worker_example.dart      # the VM
//     dart run tool/example_web_run.dart [--wasm]     # a headless Chrome
// ignore_for_file: avoid_print
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:tekartik_pitch_web_worker/pitch_worker.dart';

const _isWeb = bool.fromEnvironment('dart.library.js_interop');
const _sampleRate = 44100;

/// C4, E4, G4, C5: half a second each.
const _melody = [261.63, 329.63, 392.0, 523.25];
const _noteSeconds = 0.5;

Future<void> main() async {
  var samples = Float32List.fromList([
    for (var frequency in _melody)
      ...PitchSignal.tone(frequency, seconds: _noteSeconds),
  ]);
  var processor = PitchWorkerProcessor();
  var offThread = await processor.ready;
  print(
    'analysing ${(samples.length / _sampleRate).toStringAsFixed(1)} s '
    '${offThread ? (_isWeb ? 'in a web worker' : 'in an isolate') : 'on the main thread (no $pitchWorkerJsFilename)'}',
  );
  var session = await processor.open(
    PitchRunner(
      sampleRate: _sampleRate,
      analyses: const [PitchAnalysis('yin', YinPitchAlgorithm())],
    ),
  );
  var steps = <PitchStep>[];
  var subscription = session.steps.listen(steps.add);
  var stopwatch = Stopwatch()..start();
  for (var start = 0; start < samples.length; start += 4096) {
    // A copy: the session may take the samples over.
    session.add(
      Float32List.fromList(
        Float32List.sublistView(
          samples,
          start,
          math.min(start + 4096, samples.length),
        ),
      ),
    );
  }
  var expected = samples.length ~/ 2048;
  var deadline = DateTime.now().add(const Duration(seconds: 20));
  while (steps.length < expected && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await session.close();
  await subscription.cancel();
  await processor.close();

  // The most frequent note of the steps of each half second.
  var notes = <String>[];
  for (var index = 0; index < _melody.length; index++) {
    var counts = <String, int>{};
    for (var step in steps) {
      var estimate = step.results['yin'];
      if (step.sample ~/ (_noteSeconds * _sampleRate) == index &&
          estimate is PitchEstimate) {
        var name = pitchNoteName(estimate.note());
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    var best = counts.entries.fold<MapEntry<String, int>?>(
      null,
      (best, entry) => best == null || entry.value > best.value ? entry : best,
    );
    notes.add(best?.key ?? '-');
  }
  print(
    '${steps.length} steps in ${stopwatch.elapsedMilliseconds} ms: '
    '${notes.join(' ')}',
  );
}
