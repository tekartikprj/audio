import 'dart:math' as math;
import 'dart:typed_data';

import '../algorithm.dart';
import '../frame.dart';
import '../result.dart';

double _double(Object? value, double defaultValue) =>
    (value as num?)?.toDouble() ?? defaultValue;

/// Several targets at once (the strings of a guitar): for each target,
/// the frequency near it whose harmonics hold the most energy, and how
/// many cents it is off.
///
/// Each [PitchTarget] has a clarity (its peak over the noise floor of its
/// search window: about 0 for noise, 0.9 and more for a clean string) and a level (its peak against the loudest
/// target: a string that does not sound is low); [PitchTarget.sounds]
/// combines them.
class PolyTunerPitchAlgorithm extends PitchAlgorithm<PitchTargets> {
  /// The JSON type.
  static const jsonType = 'poly_tuner';

  /// The frequencies aimed at, in Hz.
  final List<double> targets;

  /// The search window each side of a target, in cents.
  final double searchCents;

  /// The harmonics scored.
  final int harmonics;

  /// The FFT size (a power of two; 32768 for the low strings to the cent).
  final int fftSize;

  /// The RMS level under which nothing is heard.
  final double minLevel;

  /// The [targets] (Hz) searched [searchCents] each side, scored on
  /// [harmonics] harmonics in the spectrum of the last [fftSize] samples,
  /// nothing under the RMS level [minLevel].
  const PolyTunerPitchAlgorithm({
    required this.targets,
    this.searchCents = 100,
    this.harmonics = 3,
    this.fftSize = 8192,
    this.minLevel = 0.004,
  });

  /// The algorithm of a JSON form made by [toJson].
  factory PolyTunerPitchAlgorithm.fromJson(Map<String, Object?> json) =>
      PolyTunerPitchAlgorithm(
        targets: [
          for (var target in json['targets'] as List)
            (target as num).toDouble(),
        ],
        searchCents: _double(json['searchCents'], 100),
        harmonics: (json['harmonics'] as int?) ?? 3,
        fftSize: (json['fftSize'] as int?) ?? 8192,
        minLevel: _double(json['minLevel'], 0.004),
      );

  @override
  String get type => jsonType;

  @override
  int windowSize(int sampleRate) => fftSize;

  @override
  PitchTargets? analyze(PitchFrame frame, {PitchStep? step}) {
    var spectrum = frame.spectrum(fftSize);
    if (spectrum.level < minLevel) {
      return null;
    }
    var found = [
      for (var target in targets)
        _target(spectrum.magnitudes, spectrum, target),
    ];
    // The level of each target: its peak against the loudest one.
    var loudest = found.fold(0.0, (max, item) => math.max(max, item.peak));
    return PitchTargets([
      for (var (:target, :peak) in found)
        PitchTarget(
          target.target,
          target.frequency,
          clarity: target.clarity,
          level: loudest > 0 ? peak / loudest : 0,
        ),
    ]);
  }

  ({PitchTarget target, double peak}) _target(
    Float64List magnitudes,
    PitchSpectrum spectrum,
    double target,
  ) {
    var found = _find(magnitudes, spectrum, target);
    var frequency = found.frequency;
    var peak = frequency == null
        ? 0.0
        : magnitudes[(frequency / spectrum.binHertz).round()];
    return (target: found, peak: peak);
  }

  PitchTarget _find(
    Float64List magnitudes,
    PitchSpectrum spectrum,
    double target,
  ) {
    var bin = spectrum.binHertz;
    var ratio = math.pow(2, searchCents / 1200).toDouble();
    var low = math.max(1, (target / ratio / bin).floor());
    var high = math.min(magnitudes.length - 2, (target * ratio / bin).ceil());
    if (low > high) {
      return PitchTarget(target, null);
    }
    var peak = low;
    var peakScore = 0.0;
    for (var k = low; k <= high; k++) {
      var score = 0.0;
      for (var h = 1; h <= harmonics; h++) {
        score += magnitudes[math.min(k * h, magnitudes.length - 1)];
      }
      if (score > peakScore) {
        peakScore = score;
        peak = k;
      }
    }
    if (peakScore == 0) {
      return PitchTarget(target, null);
    }
    var refined = peak.toDouble();
    var s0 = magnitudes[peak - 1];
    var s1 = magnitudes[peak];
    var s2 = magnitudes[peak + 1];
    var divisor = 2 * (2 * s1 - s2 - s0);
    if (divisor != 0) {
      refined = peak + ((s2 - s0) / divisor).clamp(-1.0, 1.0);
    }
    // The peak over the noise floor around it (the median of its window,
    // 16 bins each side at least): noise peaks reach about 3 times it,
    // clarity 0; a clean string 30 times, 0.9.
    var floorLow = math.max(1, math.min(low, peak - 16));
    var floorHigh = math.min(magnitudes.length - 1, math.max(high, peak + 16));
    var floor = (Float64List.fromList(
      Float64List.sublistView(magnitudes, floorLow, floorHigh + 1),
    )..sort())[(floorHigh - floorLow + 1) ~/ 2];
    var top = magnitudes[peak];
    var clarity = top > 0 ? (1 - 3 * floor / top).clamp(0.0, 1.0) : 0.0;
    return PitchTarget(target, refined * bin, clarity: clarity);
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'targets': targets,
    'searchCents': searchCents,
    'harmonics': harmonics,
    'fftSize': fftSize,
    'minLevel': minLevel,
  };
}
