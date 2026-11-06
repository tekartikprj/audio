import 'frame.dart';
import 'registry.dart';
import 'result.dart';

/// A pitch algorithm: what it needs ([windowSize]), what it finds
/// ([analyze]) and its settings as JSON ([toJson], read back by
/// [pitchAlgorithmFromJson]: a web worker cannot receive closures).
abstract class PitchAlgorithm<T extends PitchResult> {
  /// An algorithm.
  const PitchAlgorithm();

  /// Its type, the `type` key of its JSON form (`yin`, `reeds`...).
  String get type;

  /// The samples it analyzes at [sampleRate] (the runner keeps at least
  /// this many).
  int windowSize(int sampleRate);

  /// What [frame] holds, null when nothing is found; [step] holds the
  /// results of the analyses run before it in the same step of a runner.
  T? analyze(PitchFrame frame, {PitchStep? step});

  /// The same algorithm with A4 at [a4] Hz (itself when A4 does not
  /// matter to it).
  PitchAlgorithm<T> withA4(double a4) => this;

  /// Its settings, with its [type].
  Map<String, Object?> toJson();

  @override
  String toString() => '$runtimeType${toJson()}';
}

/// An algorithm run by a runner under an [id], its results keyed by it.
class PitchAnalysis {
  /// The id of its results.
  final String id;

  /// The algorithm.
  final PitchAlgorithm algorithm;

  /// [algorithm] run under [id].
  const PitchAnalysis(this.id, this.algorithm);

  /// The analysis of a JSON form made by [toJson].
  factory PitchAnalysis.fromJson(Map<String, Object?> json) => PitchAnalysis(
    json['id'] as String,
    pitchAlgorithmFromJson((json['algorithm'] as Map).cast<String, Object?>()),
  );

  /// The JSON form.
  Map<String, Object?> toJson() => {'id': id, 'algorithm': algorithm.toJson()};

  @override
  String toString() => 'PitchAnalysis($id, $algorithm)';
}

/// What the analyses of a runner found at a step.
class PitchStep {
  /// The samples received when analyzed (the end of the frame).
  final int sample;

  /// The sample rate.
  final int sampleRate;

  /// The RMS level of the samples received since the previous step.
  final double level;

  /// The largest absolute sample since the previous step (1 at full
  /// scale).
  final double peak;

  /// The result of each analysis by id (null: nothing found).
  final Map<String, PitchResult?> results;

  /// The samples each analysis looked at by id (the end of the frame
  /// back), when known.
  final Map<String, int>? windows;

  /// The microseconds each analysis took by id, when timed.
  final Map<String, int>? micros;

  /// The step ending at [sample] (at [sampleRate]), [level] the RMS level
  /// and [peak] the largest absolute sample since the previous step,
  /// [results], [windows] and [micros] by analysis id.
  PitchStep({
    required this.sample,
    required this.sampleRate,
    required this.level,
    this.peak = 0,
    Map<String, PitchResult?>? results,
    this.windows,
    this.micros,
  }) : results = results ?? {};

  /// The step of a JSON form made by [toJson].
  factory PitchStep.fromJson(Map<String, Object?> json) => PitchStep(
    sample: json['sample'] as int,
    sampleRate: json['sampleRate'] as int,
    level: (json['level'] as num).toDouble(),
    peak: (json['peak'] as num?)?.toDouble() ?? 0,
    results: {
      for (var MapEntry(:key, :value) in (json['results'] as Map).entries)
        key as String: value == null
            ? null
            : PitchResult.fromJson((value as Map).cast<String, Object?>()),
    },
    windows: (json['windows'] as Map?)?.cast<String, int>(),
    micros: (json['micros'] as Map?)?.cast<String, int>(),
  );

  /// The time of the end of the frame, in seconds from the start.
  double get time => sample / sampleRate;

  /// The [level] in decibels from full scale (-inf for silence; a quiet
  /// room is about -60, a note played near the microphone -30 to -10).
  double get decibels => pitchDecibels(level);

  /// True when the sound reaches [threshold] of full scale: it is clipped
  /// (too loud, too near), the analyses suffer.
  bool clipped({double threshold = 0.99}) => peak >= threshold;

  /// When the sound analyzed by [id] was heard, in seconds from the start:
  /// the middle of its window (the time of the step when unknown). A
  /// display lags by [time] minus this, plus the input latency.
  double heardAt(String id) {
    var window = windows?[id];
    return window == null ? time : (sample - window / 2) / sampleRate;
  }

  /// The result of the analysis [id] when it is a [T], else null.
  T? result<T extends PitchResult>(String id) {
    var result = results[id];
    return result is T ? result : null;
  }

  /// The JSON form.
  Map<String, Object?> toJson() => {
    'sample': sample,
    'sampleRate': sampleRate,
    'level': level,
    'peak': peak,
    'results': {
      for (var MapEntry(:key, :value) in results.entries) key: value?.toJson(),
    },
    if (windows != null) 'windows': windows,
    if (micros != null) 'micros': micros,
  };

  @override
  String toString() =>
      'PitchStep(${time.toStringAsFixed(3)} s, level '
      '${level.toStringAsFixed(3)}, $results)';
}
