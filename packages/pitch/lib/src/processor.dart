import 'dart:async';
import 'dart:typed_data';

import 'algorithm.dart';
import 'runner.dart';

/// A stream of chunks being analyzed somewhere (here, in a web worker, in
/// an isolate): chunks in ([add]), steps out ([steps]), in order.
abstract class PitchSession {
  /// The steps of the chunks added, in order.
  Stream<PitchStep> get steps;

  /// Analyzes [samples] (mono, -1 to 1, at the sample rate of the runner).
  /// A session in another thread may take the samples over: do not reuse
  /// [samples] after.
  void add(Float32List samples);

  /// Replaces the analyses (A4 changed, another tuning), from the next
  /// chunk on.
  void setAnalyses(List<PitchAnalysis> analyses);

  /// Ends the session: no more steps, [steps] ends.
  Future<void> close();
}

/// Where the analyses of a [PitchRunner] run: here ([PitchProcessor.local]),
/// in a web worker or an isolate (`tekartik_pitch_web_worker`).
abstract class PitchProcessor {
  /// A processor.
  const PitchProcessor();

  /// The processor running the analyses in the calling thread.
  static const PitchProcessor local = _LocalPitchProcessor();

  /// Opens a session running [runner] (its settings: sample rate, hop,
  /// analyses; a processor in another thread rebuilds it from its JSON
  /// form).
  Future<PitchSession> open(PitchRunner runner);

  /// True when the analyses run off the calling thread (once [open] was
  /// called: a worker that could not start falls back on the calling
  /// thread).
  bool get offThread => false;
}

class _LocalPitchProcessor extends PitchProcessor {
  const _LocalPitchProcessor();

  @override
  Future<PitchSession> open(PitchRunner runner) async =>
      PitchLocalSession(runner);
}

/// A session running its runner in the calling thread, its steps given at
/// once.
class PitchLocalSession implements PitchSession {
  /// The runner.
  final PitchRunner runner;

  final _steps = StreamController<PitchStep>(sync: true);

  /// A session of [runner].
  PitchLocalSession(this.runner);

  @override
  Stream<PitchStep> get steps => _steps.stream;

  @override
  void add(Float32List samples) {
    if (_steps.isClosed) {
      return;
    }
    for (var step in runner.add(samples)) {
      _steps.add(step);
    }
  }

  @override
  void setAnalyses(List<PitchAnalysis> analyses) {
    runner.analyses = analyses;
  }

  @override
  Future<void> close() async {
    // Not awaited: the done event may never be delivered (a listener
    // gone), the steps simply end.
    unawaited(_steps.close());
  }
}
