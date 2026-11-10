import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tekartik_audio_input/audio_input.dart';
import 'package:tekartik_pitch/pitch.dart';

/// Listens to an [input] and runs pitch analyses on it: its state, the
/// level of the sound (at each chunk, for a direct feedback) and the last
/// step as [ValueNotifier]s for the widgets, each step given to [onStep].
class PitchListening {
  /// The input, null when the platform has none (the state goes to
  /// failed when started).
  final AudioInput? input;

  /// The samples between two steps.
  final int hop;

  /// True to time each analysis.
  final bool timed;

  /// The state of the input.
  final state = ValueNotifier(AudioInputState.off);

  /// The level of the sound, at each chunk ([AudioLevel.silence] when not
  /// listening).
  final level = ValueNotifier(AudioLevel.silence);

  /// The last step, null when not listening.
  final step = ValueNotifier<PitchStep?>(null);

  /// Called with each step.
  void Function(PitchStep step)? onStep;

  /// The error of the last start, when it failed or was denied.
  Object? error;

  /// Where the analyses run: here by default, in a web worker or an
  /// isolate with a `PitchWorkerProcessor` (tekartik_pitch_web_worker).
  final PitchProcessor processor;

  List<PitchAnalysis> _analyses;
  double _a4;
  PitchSession? _session;
  StreamSubscription<PitchStep>? _stepSubscription;
  StreamSubscription<Float32List>? _subscription;
  final AudioInputMetered? _metered;
  StreamSubscription<AudioLevel>? _levelSubscription;

  /// Bumped by [stop] (and [dispose]): a [start] still waiting (for the
  /// microphone permission, the worker) gives up when it changed.
  var _startId = 0;
  var _disposed = false;

  /// Listening to [input] (measured, see [level]) with [analyses], A4 at
  /// [a4] Hz, a step every [hop] samples, each analysis timed when
  /// [timed], run by [processor] (here by default).
  PitchListening(
    this.input, {
    required List<PitchAnalysis> analyses,
    this.hop = 2048,
    double a4 = 440,
    this.timed = false,
    this.processor = PitchProcessor.local,
  }) : _analyses = [
         for (var analysis in analyses)
           PitchAnalysis(analysis.id, analysis.algorithm.withA4(a4)),
       ],
       _a4 = a4,
       _metered = switch (input) {
         null => null,
         AudioInputMetered metered => metered,
         var input => AudioInputMetered(input),
       } {
    _levelSubscription = _metered?.levels.listen(
      (level) => this.level.value = level,
    );
  }

  /// A4, in Hz.
  double get a4 => _a4;

  /// Sets A4 at [a4] Hz in the analyses that use it, at once when
  /// listening.
  set a4(double a4) {
    if (a4 == _a4) {
      return;
    }
    _a4 = a4;
    analyses = [
      for (var analysis in _analyses)
        PitchAnalysis(analysis.id, analysis.algorithm.withA4(a4)),
    ];
  }

  /// The analyses.
  List<PitchAnalysis> get analyses => List.unmodifiable(_analyses);

  /// Replaces the analyses, at once when listening.
  set analyses(List<PitchAnalysis> analyses) {
    _analyses = List.of(analyses);
    _session?.setAnalyses(_analyses);
  }

  /// True while listening.
  bool get isOn => state.value == AudioInputState.on;

  /// How late the samples come from the input, in seconds.
  double get latency => input?.latency ?? 0;

  /// How long ago, in seconds, the sound analyzed by [id] in [step] was
  /// heard, when [step] arrives: the input latency plus half the window of
  /// the analysis.
  double ago(PitchStep step, String id) =>
      latency + step.time - step.heardAt(id);

  /// Starts listening (from a user gesture: the web asks for the
  /// microphone); the state tells how it went.
  ///
  /// A [stop] or a [dispose] while it starts wins: the input is stopped
  /// once started, the state stays off.
  Future<void> start() async {
    if (_disposed) {
      return;
    }
    var input = _metered;
    if (input == null) {
      error = const AudioInputUnavailable('no input');
      state.value = AudioInputState.failed;
      return;
    }
    if (state.value == AudioInputState.on ||
        state.value == AudioInputState.starting) {
      return;
    }
    var startId = ++_startId;
    bool stopped() => startId != _startId;
    error = null;
    state.value = AudioInputState.starting;
    try {
      var chunks = await input.start();
      if (stopped()) {
        _stopStartedInput(input, chunks);
        return;
      }
      var session = await processor.open(
        PitchRunner(
          sampleRate: input.sampleRate,
          analyses: _analyses,
          hop: hop,
          timed: timed,
        ),
      );
      if (stopped()) {
        unawaited(session.close());
        _stopStartedInput(input, chunks);
        return;
      }
      _session = session;
      _stepSubscription = session.steps.listen((step) {
        this.step.value = step;
        onStep?.call(step);
      }, onError: (Object e) => debugPrint('pitch listening: $e'));
      _subscription = chunks.listen(
        session.add,
        onDone: () {
          if (state.value == AudioInputState.on) {
            state.value = AudioInputState.off;
          }
        },
      );
      state.value = AudioInputState.on;
    } on AudioInputDenied catch (e) {
      if (stopped()) {
        return;
      }
      error = e;
      state.value = AudioInputState.denied;
    } catch (e) {
      if (stopped()) {
        return;
      }
      error = e;
      state.value = AudioInputState.failed;
    }
  }

  /// Stops [input] (its [chunks] never listened), started by a [start] that
  /// a [stop] superseded. Not awaited: an input closing a stream nobody
  /// listened to can wait for ever.
  void _stopStartedInput(AudioInput input, Stream<Float32List> chunks) {
    unawaited(chunks.listen(null).cancel());
    unawaited(
      input.stop().catchError(
        (Object e) => debugPrint('pitch listening stop: $e'),
      ),
    );
  }

  /// Stops listening (a [start] in progress included).
  Future<void> stop() async {
    _startId++;
    step.value = null;
    if (state.value == AudioInputState.on ||
        state.value == AudioInputState.starting) {
      state.value = AudioInputState.off;
    }
    // Not awaited: the input stops right after, and an awaited cancel
    // hangs the awaits after it in a widget test (a completed root zone
    // future).
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_stepSubscription?.cancel());
    _stepSubscription = null;
    unawaited(_session?.close());
    _session = null;
    try {
      await _metered?.stop();
    } catch (e) {
      debugPrint('pitch listening stop: $e');
    }
  }

  /// Stops and frees the notifiers (and the meter it made).
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    unawaited(_levelSubscription?.cancel());
    var metered = _metered;
    if (metered != null && !identical(metered, input)) {
      await metered.close();
    }
    state.dispose();
    level.dispose();
    step.dispose();
  }
}
