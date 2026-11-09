import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:tekartik_pitch_web_worker/pitch_worker.dart';
import 'package:test/test.dart';

const _isWeb = bool.fromEnvironment('dart.library.js_interop');

PitchRunner _runner() => PitchRunner(
  sampleRate: 44100,
  analyses: const [
    PitchAnalysis('yin', YinPitchAlgorithm()),
    PitchAnalysis('reeds', ReedsPitchAlgorithm(source: 'yin')),
  ],
);

void main() {
  group('PitchWorkerProcessor', () {
    late PitchWorkerProcessor processor;
    late bool running;
    setUpAll(() async {
      // test/pitch_worker.js on the web, built by tool/dev_build_setup.dart.
      processor = PitchWorkerProcessor(fallback: false);
      running = await processor.ready;
    });
    tearDownAll(() => processor.close());

    test('a musette off the main thread, analyses replaced', () async {
      if (!running) {
        markTestSkipped(
          'test/$pitchWorkerJsFilename not built: '
          'dart run tool/dev_build_setup.dart',
        );
        return;
      }
      var session = await processor.open(_runner());
      expect(processor.offThread, isTrue);
      var steps = <PitchStep>[];
      var subscription = session.steps.listen(steps.add);
      var samples = PitchSignal.reeds(440, [-19.6, 0, 19.6]);
      var expected = samples.length ~/ 2048;
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
      var deadline = DateTime.now().add(const Duration(seconds: 20));
      while (steps.length < expected && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(steps, hasLength(expected));
      var reeds = steps.last.result<PitchReeds>('reeds')!;
      expect(reeds.reeds.map((reed) => reed.cents.round()), [-20, 0, 20]);
      session.setAnalyses(const [PitchAnalysis('yin', YinPitchAlgorithm())]);
      session.add(Float32List(2048));
      deadline = DateTime.now().add(const Duration(seconds: 10));
      while (steps.length <= expected && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(steps.last.results.keys, ['yin']);
      await session.close();
      await subscription.cancel();
    });

    test('closed: no more sessions', () async {
      var other = PitchWorkerProcessor();
      await other.close();
      expect(() => other.open(_runner()), throwsStateError);
    });
  });

  test('a missing script: the main thread, or an error', () async {
    if (!_isWeb) {
      return;
    }
    var processor = PitchWorkerProcessor(url: 'missing_pitch_worker.js');
    expect(await processor.ready, isFalse);
    var session = await processor.open(_runner());
    expect(processor.offThread, isFalse);
    expect(session, isA<PitchLocalSession>());
    var strict = PitchWorkerProcessor(
      url: 'missing_pitch_worker.js',
      fallback: false,
    );
    expect(() => strict.open(_runner()), throwsStateError);
  });

  test('errors', () {
    expect(
      PitchWorkerException('broken').toString(),
      'PitchWorkerException: broken',
    );
    expect(pitchWorkerProtocolVersion, 1);
  });

  // The web worker sends its errors back (worker_main.dart): the isolate
  // too. A custom algorithm cannot go to the web worker (JSON).
  test('io: an analysis error reaches the steps', () async {
    var processor = PitchWorkerProcessor();
    try {
      var session = await processor.open(
        PitchRunner(
          sampleRate: 44100,
          analyses: const [PitchAnalysis('broken', _BrokenAlgorithm())],
        ),
      );
      var error = Completer<Object>();
      var subscription = session.steps.listen(
        (_) {},
        onError: (Object e) {
          if (!error.isCompleted) {
            error.complete(e);
          }
        },
      );
      session.add(Float32List(4096));
      expect(
        await error.future.timeout(const Duration(seconds: 10)),
        isA<PitchWorkerException>().having(
          (e) => e.message,
          'message',
          contains('broken analysis'),
        ),
      );
      await subscription.cancel();
    } finally {
      await processor.close();
    }
  }, testOn: 'vm');
}

class _BrokenAlgorithm extends PitchAlgorithm<PitchResult> {
  const _BrokenAlgorithm();

  @override
  String get type => 'broken';

  @override
  int windowSize(int sampleRate) => 1024;

  @override
  PitchResult? analyze(PitchFrame frame, {PitchStep? step}) =>
      throw StateError('broken analysis');

  @override
  Map<String, Object?> toJson() => {'type': type};
}
