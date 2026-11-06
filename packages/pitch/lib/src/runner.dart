import 'dart:math' as math;
import 'dart:typed_data';

import 'algorithm.dart';
import 'frame.dart';
import 'ring.dart';

/// Runs several analyses on the same sound: chunks of samples in, a step
/// every [hop] samples out (at the multiples of [hop], whatever the size
/// of the chunks), each analysis given a frame of the latest samples
/// (sharing their spectra) and the results of the analyses before it.
class PitchRunner {
  /// The sample rate of the chunks.
  final int sampleRate;

  /// The samples between two steps.
  final int hop;

  /// True to time each analysis ([PitchStep.micros]).
  final bool timed;

  /// The most steps a chunk gives: when a chunk spans more hops (a busy
  /// page catching up), only its last [maxBehind] steps are analyzed.
  final int maxBehind;

  List<PitchAnalysis> _analyses;
  PitchSampleRing _ring;
  var _next = 0;

  /// A runner of [analyses] (run in this order) on chunks at [sampleRate],
  /// a step every [hop] samples, at most [maxBehind] steps per chunk, each
  /// analysis timed when [timed].
  PitchRunner({
    required this.sampleRate,
    required List<PitchAnalysis> analyses,
    this.hop = 2048,
    this.timed = false,
    this.maxBehind = 4,
  }) : _analyses = List.of(analyses),
       _ring = PitchSampleRing(_capacity(analyses, sampleRate, hop)) {
    _next = hop;
  }

  /// The runner of a JSON form made by [toJson].
  factory PitchRunner.fromJson(Map<String, Object?> json) => PitchRunner(
    sampleRate: json['sampleRate'] as int,
    hop: (json['hop'] as int?) ?? 2048,
    timed: (json['timed'] as bool?) ?? false,
    maxBehind: (json['maxBehind'] as int?) ?? 4,
    analyses: [
      for (var analysis in json['analyses'] as List)
        PitchAnalysis.fromJson((analysis as Map).cast<String, Object?>()),
    ],
  );

  static int _capacity(List<PitchAnalysis> analyses, int sampleRate, int hop) =>
      _windowSize(analyses, sampleRate) + hop;

  static int _windowSize(List<PitchAnalysis> analyses, int sampleRate) =>
      analyses.fold(
        0,
        (size, analysis) =>
            math.max(size, analysis.algorithm.windowSize(sampleRate)),
      );

  /// The analyses, run in this order.
  List<PitchAnalysis> get analyses => List.unmodifiable(_analyses);

  /// Replaces the analyses (the samples received are kept).
  set analyses(List<PitchAnalysis> analyses) {
    _analyses = List.of(analyses);
    var capacity = _capacity(_analyses, sampleRate, hop);
    if (capacity > _ring.capacity) {
      var ring = PitchSampleRing(capacity)
        ..add(_ring.latest(_ring.capacity))
        ..received = _ring.received;
      _ring = ring;
    }
  }

  /// Sets A4 at [a4] Hz in the analyses that use it.
  void setA4(double a4) {
    analyses = [
      for (var analysis in _analyses)
        PitchAnalysis(analysis.id, analysis.algorithm.withA4(a4)),
    ];
  }

  /// The samples the frames hold: the largest window of the analyses.
  int get windowSize => _windowSize(_analyses, sampleRate);

  /// The samples received since the start (or the last [reset]).
  int get received => _ring.received;

  /// Adds a chunk of [samples]: the steps due, each ending exactly at its
  /// multiple of [hop]; only the last [maxBehind] when the chunk spans more
  /// hops.
  List<PitchStep> add(Float32List samples) {
    var start = _ring.received;
    var end = start + samples.length;
    if (end < _next) {
      _ring.add(samples);
      return const [];
    }
    // The steps due in this chunk, the late ones skipped.
    var due = (end - _next) ~/ hop + 1;
    if (due > maxBehind) {
      _next += (due - maxBehind) * hop;
    }
    var steps = <PitchStep>[];
    var offset = 0;
    while (_next <= end) {
      var to = _next - start;
      _ring.add(Float32List.sublistView(samples, offset, to));
      offset = to;
      steps.add(_step());
      _next += hop;
    }
    _ring.add(Float32List.sublistView(samples, offset));
    return steps;
  }

  /// The steps of a stream of chunks.
  Stream<PitchStep> bind(Stream<Float32List> chunks) =>
      chunks.expand((chunk) => add(chunk));

  /// Forgets the samples received.
  void reset() {
    _ring.clear();
    _next = hop;
  }

  PitchStep _step() {
    var size = windowSize;
    var frame = PitchFrame(_ring.latest(size), sampleRate: sampleRate);
    var last = frame.latest(math.min(hop, size));
    var step = PitchStep(
      sample: _ring.received,
      sampleRate: sampleRate,
      level: pitchLevel(last),
      peak: pitchPeak(last),
      windows: {
        for (var analysis in _analyses)
          analysis.id: analysis.algorithm.windowSize(sampleRate),
      },
      micros: timed ? {} : null,
    );
    var stopwatch = timed ? Stopwatch() : null;
    for (var analysis in _analyses) {
      stopwatch?.reset();
      stopwatch?.start();
      step.results[analysis.id] = analysis.algorithm.analyze(frame, step: step);
      if (stopwatch != null) {
        step.micros![analysis.id] = stopwatch.elapsedMicroseconds;
      }
    }
    return step;
  }

  /// The JSON form of its settings.
  Map<String, Object?> toJson() => {
    'sampleRate': sampleRate,
    'hop': hop,
    'timed': timed,
    'maxBehind': maxBehind,
    'analyses': [for (var analysis in _analyses) analysis.toJson()],
  };
}
