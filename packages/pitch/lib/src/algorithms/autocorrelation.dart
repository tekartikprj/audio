import 'dart:math' as math;
import 'dart:typed_data';

import '../algorithm.dart';
import '../frame.dart';
import '../result.dart';

double _double(Object? value, double defaultValue) =>
    (value as num?)?.toDouble() ?? defaultValue;

/// The pitch of one note by normalized autocorrelation: simple, a little
/// less accurate than YIN (a cent or two), weaker on noise.
///
/// Clarity: the correlation at the period scaled from [threshold] (0) to
/// a perfectly periodic sound (1); above 0.8 a clean note.
class AutocorrelationPitchAlgorithm extends PitchAlgorithm<PitchEstimate> {
  /// The JSON type.
  static const jsonType = 'autocorrelation';

  /// The lowest frequency found, in Hz.
  final double minFrequency;

  /// The highest frequency found, in Hz.
  final double maxFrequency;

  /// The normalized correlation a peak needs, 0 to 1.
  final double threshold;

  /// The samples analyzed.
  final int size;

  /// The RMS level under which nothing is heard.
  final double minLevel;

  /// Autocorrelation of the last [size] samples, from [minFrequency] to
  /// [maxFrequency] Hz, a peak above [threshold] taken, nothing under the
  /// RMS level [minLevel].
  const AutocorrelationPitchAlgorithm({
    this.minFrequency = 50,
    this.maxFrequency = 2000,
    this.threshold = 0.5,
    this.size = 4096,
    this.minLevel = 0.004,
  });

  /// The algorithm of a JSON form made by [toJson].
  factory AutocorrelationPitchAlgorithm.fromJson(Map<String, Object?> json) =>
      AutocorrelationPitchAlgorithm(
        minFrequency: _double(json['minFrequency'], 50),
        maxFrequency: _double(json['maxFrequency'], 2000),
        threshold: _double(json['threshold'], 0.5),
        size: (json['size'] as int?) ?? 4096,
        minLevel: _double(json['minLevel'], 0.004),
      );

  @override
  String get type => jsonType;

  @override
  int windowSize(int sampleRate) => size;

  @override
  PitchEstimate? analyze(PitchFrame frame, {PitchStep? step}) =>
      detect(frame.latest(size), frame.sampleRate);

  /// The pitch of [samples] at [sampleRate], null when none.
  PitchEstimate? detect(Float32List samples, int sampleRate) {
    var n = samples.length;
    var level = pitchLevel(samples);
    if (n < 2 || level < minLevel) {
      return null;
    }
    var minLag = (sampleRate / maxFrequency).ceil();
    var maxLag = math.min((sampleRate / minFrequency).floor(), n - 1);
    if (minLag > maxLag) {
      return null;
    }
    var r0 = _correlation(samples, 0);
    if (r0 == 0) {
      return null;
    }
    // Past the central lobe (the correlation of a sound with itself barely
    // shifted): from its first dip below zero, or its first minimum.
    var start = minLag;
    var previous = _correlation(samples, start);
    while (start < maxLag) {
      var next = _correlation(samples, start + 1);
      if (previous <= 0 || next > previous) {
        break;
      }
      previous = next;
      start++;
    }
    var bestLag = start;
    var best = double.negativeInfinity;
    for (var lag = start; lag <= maxLag; lag++) {
      var r = _correlation(samples, lag) / r0;
      if (r > best) {
        best = r;
        bestLag = lag;
      }
    }
    if (best < threshold) {
      return null;
    }
    // Between the samples: a parabola through the peak.
    var lag = bestLag.toDouble();
    if (bestLag > minLag && bestLag < maxLag) {
      var s0 = _correlation(samples, bestLag - 1) / r0;
      var s2 = _correlation(samples, bestLag + 1) / r0;
      var divisor = 2 * (2 * best - s2 - s0);
      if (divisor != 0) {
        lag = bestLag - (s2 - s0) / divisor;
      }
    }
    var clarity = ((best - threshold) / (1 - threshold)).clamp(0.0, 1.0);
    return PitchEstimate(sampleRate / lag, clarity: clarity, level: level);
  }

  double _correlation(Float32List samples, int lag) {
    var sum = 0.0;
    var end = samples.length - lag;
    for (var i = 0; i < end; i++) {
      sum += samples[i] * samples[i + lag];
    }
    return sum;
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'minFrequency': minFrequency,
    'maxFrequency': maxFrequency,
    'threshold': threshold,
    'size': size,
    'minLevel': minLevel,
  };
}
