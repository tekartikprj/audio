import 'dart:math' as math;
import 'dart:typed_data';

import '../algorithm.dart';
import '../frame.dart';
import '../result.dart';

double _double(Object? value, double defaultValue) =>
    (value as num?)?.toDouble() ?? defaultValue;

/// Several notes at once by spectral peeling (matching pursuit): the
/// strongest fundamental with its harmonics is found, recorded and removed
/// from the spectrum, then the next one.
///
/// Clarity of each note: its peak against the strongest one (1 for the
/// loudest note), not how clean it is.
class HarmonicPeelingPitchAlgorithm extends PitchAlgorithm<PitchEstimates> {
  /// The JSON type.
  static const jsonType = 'harmonic_peeling';

  /// The FFT size (a power of two; 32768 tells the low strings apart).
  final int fftSize;

  /// The lowest frequency found, in Hz.
  final double minFrequency;

  /// The highest frequency found, in Hz.
  final double maxFrequency;

  /// The harmonics scored and peeled with a fundamental.
  final int harmonics;

  /// A candidate is ignored under this share of the strongest peak.
  final double peakThreshold;

  /// The most notes found.
  final int maxPitches;

  /// The RMS level under which nothing is heard.
  final double minLevel;

  /// Up to [maxPitches] notes from [minFrequency] to [maxFrequency] Hz in
  /// the spectrum of the last [fftSize] samples, [harmonics] peeled with
  /// each, candidates under [peakThreshold] of the strongest peak ignored,
  /// nothing under the RMS level [minLevel].
  const HarmonicPeelingPitchAlgorithm({
    this.fftSize = 16384,
    this.minFrequency = 50,
    this.maxFrequency = 1000,
    this.harmonics = 6,
    this.peakThreshold = 0.08,
    this.maxPitches = 6,
    this.minLevel = 0.004,
  });

  /// The algorithm of a JSON form made by [toJson].
  factory HarmonicPeelingPitchAlgorithm.fromJson(Map<String, Object?> json) =>
      HarmonicPeelingPitchAlgorithm(
        fftSize: (json['fftSize'] as int?) ?? 16384,
        minFrequency: _double(json['minFrequency'], 50),
        maxFrequency: _double(json['maxFrequency'], 1000),
        harmonics: (json['harmonics'] as int?) ?? 6,
        peakThreshold: _double(json['peakThreshold'], 0.08),
        maxPitches: (json['maxPitches'] as int?) ?? 6,
        minLevel: _double(json['minLevel'], 0.004),
      );

  @override
  String get type => jsonType;

  @override
  int windowSize(int sampleRate) => fftSize;

  @override
  PitchEstimates? analyze(PitchFrame frame, {PitchStep? step}) {
    var spectrum = frame.spectrum(fftSize);
    if (spectrum.level < minLevel) {
      return null;
    }
    var magnitudes = spectrum.magnitudes;
    var working = Float64List.fromList(magnitudes);
    var bin = spectrum.binHertz;
    var last = magnitudes.length - 2;
    var low = (minFrequency / bin).ceil().clamp(1, last);
    var high = (maxFrequency / bin).floor().clamp(1, last);
    if (low >= high) {
      return null;
    }
    var initialMax = 0.0;
    for (var i = low; i <= high; i++) {
      initialMax = math.max(initialMax, working[i]);
    }
    if (initialMax == 0) {
      return null;
    }
    var estimates = <PitchEstimate>[];
    for (var iteration = 0; iteration < maxPitches; iteration++) {
      var bestBin = -1;
      var bestScore = -1.0;
      for (var k = low; k <= high; k++) {
        if (working[k] <= working[k - 1] || working[k] <= working[k + 1]) {
          continue;
        }
        if (working[k] < initialMax * peakThreshold) {
          continue;
        }
        var score = _score(working, k);
        if (score > bestScore) {
          bestScore = score;
          bestBin = k;
        }
      }
      if (bestBin == -1) {
        break;
      }
      // The frequency from the original spectrum, between the bins.
      var refined = _parabolic(magnitudes, bestBin);
      var clarity = (working[bestBin] / initialMax).clamp(0.0, 1.0);
      estimates.add(
        PitchEstimate(refined * bin, clarity: clarity, level: spectrum.level),
      );
      _peel(working, bestBin);
    }
    estimates.sort((a, b) => a.frequency.compareTo(b.frequency));
    return PitchEstimates(estimates);
  }

  double _score(Float64List magnitudes, int bin) {
    var sum = 0.0;
    for (var h = 1; h <= harmonics; h++) {
      var target = bin * h;
      if (target >= magnitudes.length) {
        break;
      }
      var peak = 0.0;
      var from = math.max(0, target - 2);
      var to = math.min(magnitudes.length - 1, target + 2);
      for (var k = from; k <= to; k++) {
        peak = math.max(peak, magnitudes[k]);
      }
      // The low harmonics count more.
      sum += peak / h;
    }
    // Times the fundamental: a missing fundamental (a sub-harmonic) loses.
    return magnitudes[bin] * sum;
  }

  void _peel(Float64List magnitudes, int bin) {
    var fundamental = magnitudes[bin];
    _clear(magnitudes, bin, 3);
    for (var h = 2; h <= harmonics; h++) {
      var target = bin * h;
      if (target >= magnitudes.length) {
        break;
      }
      var peak = -1.0;
      var peakBin = target;
      var from = math.max(0, target - 2);
      var to = math.min(magnitudes.length - 1, target + 2);
      for (var k = from; k <= to; k++) {
        if (magnitudes[k] > peak) {
          peak = magnitudes[k];
          peakBin = k;
        }
      }
      // A plucked string's harmonics fall about as 1 / h.
      var expected = fundamental * (0.5 / h);
      if (peak > expected * 1.5) {
        // Another note sounds here too: only its expected share removed.
        var clearFrom = math.max(0, peakBin - 2);
        var clearTo = math.min(magnitudes.length - 1, peakBin + 2);
        for (var k = clearFrom; k <= clearTo; k++) {
          magnitudes[k] = math.max(0, magnitudes[k] - expected);
        }
      } else {
        _clear(magnitudes, peakBin, 3);
      }
    }
  }

  void _clear(Float64List magnitudes, int bin, int width) {
    var from = math.max(0, bin - width);
    var to = math.min(magnitudes.length - 1, bin + width);
    for (var k = from; k <= to; k++) {
      magnitudes[k] = 0;
    }
  }

  double _parabolic(Float64List magnitudes, int bin) {
    if (bin <= 0 || bin >= magnitudes.length - 1) {
      return bin.toDouble();
    }
    var s0 = magnitudes[bin - 1];
    var s1 = magnitudes[bin];
    var s2 = magnitudes[bin + 1];
    var divisor = 2 * (2 * s1 - s2 - s0);
    return divisor == 0 ? bin.toDouble() : bin + (s2 - s0) / divisor;
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'fftSize': fftSize,
    'minFrequency': minFrequency,
    'maxFrequency': maxFrequency,
    'harmonics': harmonics,
    'peakThreshold': peakThreshold,
    'maxPitches': maxPitches,
    'minLevel': minLevel,
  };
}
