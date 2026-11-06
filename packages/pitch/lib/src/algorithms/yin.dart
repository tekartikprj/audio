import 'dart:math' as math;
import 'dart:typed_data';

import '../algorithm.dart';
import '../fft.dart';
import '../frame.dart';
import '../result.dart';

double _double(Object? value, double defaultValue) =>
    (value as num?)?.toDouble() ?? defaultValue;

/// The pitch of one note to the cent: YIN (de Cheveigné and Kawahara,
/// 2002), its difference function computed with an FFT.
///
/// Clarity: 1 minus the normalized difference at the period; above 0.9 a
/// clean note, 0.8 to 0.9 noisy or beating (reeds tuned apart), under 0.8
/// better ignored. Noise gives no estimate.
class YinPitchAlgorithm extends PitchAlgorithm<PitchEstimate> {
  /// The JSON type.
  static const jsonType = 'yin';

  /// The lowest frequency found, in Hz.
  final double minFrequency;

  /// The highest frequency found, in Hz.
  final double maxFrequency;

  /// The dip of the normalized difference taken for a period (0.1 to 0.2).
  final double threshold;

  /// The RMS level under which nothing is heard.
  final double minLevel;

  /// YIN from [minFrequency] to [maxFrequency] Hz, a dip under [threshold]
  /// taken for a period, nothing under the RMS level [minLevel].
  const YinPitchAlgorithm({
    this.minFrequency = 50,
    this.maxFrequency = 2200,
    this.threshold = 0.12,
    this.minLevel = 0.004,
  });

  /// The algorithm of a JSON form made by [toJson].
  factory YinPitchAlgorithm.fromJson(Map<String, Object?> json) =>
      YinPitchAlgorithm(
        minFrequency: _double(json['minFrequency'], 50),
        maxFrequency: _double(json['maxFrequency'], 2200),
        threshold: _double(json['threshold'], 0.12),
        minLevel: _double(json['minLevel'], 0.004),
      );

  @override
  String get type => jsonType;

  /// Twice the longest period, a power of two (2048 at 44.1 kHz).
  @override
  int windowSize(int sampleRate) =>
      PitchFft.powerOfTwoAtLeast(2 * sampleRate / minFrequency, minimum: 256);

  @override
  PitchEstimate? analyze(PitchFrame frame, {PitchStep? step}) =>
      detect(frame.latest(windowSize(frame.sampleRate)), frame.sampleRate);

  /// The pitch of the last [windowSize] [samples] at [sampleRate], null
  /// when none is clear (silence, noise).
  PitchEstimate? detect(Float32List samples, int sampleRate) {
    var n = math.min(samples.length, windowSize(sampleRate));
    var x = Float32List.sublistView(samples, samples.length - n);
    var level = pitchLevel(x);
    if (level < minLevel || n < 4) {
      return null;
    }
    var maxLag = math.min((sampleRate / minFrequency).ceil(), n ~/ 2);
    var minLag = math.max(2, (sampleRate / maxFrequency).floor());
    if (minLag >= maxLag) {
      return null;
    }
    var window = n - maxLag;
    // The cross terms: the sum of x[j] * x[j + lag] for j < window.
    var size = PitchFft.powerOfTwoAtLeast(n + window);
    var fft = PitchFft(size);
    var aRe = Float64List(size);
    var aIm = Float64List(size);
    var bRe = Float64List(size);
    var bIm = Float64List(size);
    for (var i = 0; i < n; i++) {
      bRe[i] = x[i];
      if (i < window) {
        aRe[i] = x[i];
      }
    }
    fft.transform(aRe, aIm);
    fft.transform(bRe, bIm);
    for (var i = 0; i < size; i++) {
      // conj(a) * b.
      var re = aRe[i] * bRe[i] + aIm[i] * bIm[i];
      var im = aRe[i] * bIm[i] - aIm[i] * bRe[i];
      aRe[i] = re;
      aIm[i] = im;
    }
    fft.transform(aRe, aIm, inverse: true);
    // The energies of the windows, from cumulated squares.
    var squares = Float64List(n + 1);
    for (var i = 0; i < n; i++) {
      squares[i + 1] = squares[i] + x[i] * x[i];
    }
    var first = squares[window];
    // The difference and its cumulative mean normalized value.
    var differences = Float64List(maxLag + 1);
    var normalized = Float64List(maxLag + 1);
    normalized[0] = 1;
    var sum = 0.0;
    for (var lag = 1; lag <= maxLag; lag++) {
      var energy = squares[lag + window] - squares[lag];
      var difference = first + energy - 2 * aRe[lag];
      differences[lag] = difference;
      sum += difference;
      normalized[lag] = sum == 0 ? 1 : difference * lag / sum;
    }
    // The first dip under the threshold, to its bottom.
    int? found;
    for (var lag = minLag; lag < maxLag; lag++) {
      if (normalized[lag] < threshold) {
        while (lag + 1 < maxLag && normalized[lag + 1] < normalized[lag]) {
          lag++;
        }
        found = lag;
        break;
      }
    }
    if (found == null) {
      // The lowest dip, when clear enough.
      var best = minLag;
      for (var lag = minLag; lag < maxLag; lag++) {
        if (normalized[lag] < normalized[best]) {
          best = lag;
        }
      }
      if (normalized[best] > 0.3) {
        return null;
      }
      found = best;
    }
    // Between the samples: a parabola through the dip of the difference.
    var period = found.toDouble();
    if (found > 1 && found < maxLag) {
      var a = differences[found - 1];
      var b = differences[found];
      var c = differences[found + 1];
      var divisor = a - 2 * b + c;
      if (divisor > 0) {
        period += 0.5 * (a - c) / divisor;
      }
    }
    var clarity = (1 - normalized[found]).clamp(0.0, 1.0);
    return PitchEstimate(sampleRate / period, clarity: clarity, level: level);
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'minFrequency': minFrequency,
    'maxFrequency': maxFrequency,
    'threshold': threshold,
    'minLevel': minLevel,
  };
}
