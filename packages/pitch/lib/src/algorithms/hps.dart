import 'dart:math' as math;
import 'dart:typed_data';

import '../algorithm.dart';
import '../frame.dart';
import '../result.dart';

double _double(Object? value, double defaultValue) =>
    (value as num?)?.toDouble() ?? defaultValue;

/// The pitch of one note by harmonic product spectrum: the spectrum
/// multiplied by its copies compressed 2, 3... times, which reinforces the
/// fundamental; robust on sounds rich in harmonics and noise, coarse (a
/// bin of [fftSize]).
///
/// Clarity: the harmonicity of the frequency found
/// ([PitchSpectrum.harmonicity]); above 0.8 a clean note, under 0.5 mostly
/// noise.
class HpsPitchAlgorithm extends PitchAlgorithm<PitchEstimate> {
  /// The JSON type.
  static const jsonType = 'hps';

  /// The copies multiplied (2 to 5).
  final int harmonics;

  /// The lowest frequency found, in Hz.
  final double minFrequency;

  /// The highest frequency found, in Hz.
  final double maxFrequency;

  /// The FFT size (a power of two, larger is finer).
  final int fftSize;

  /// The RMS level under which nothing is heard.
  final double minLevel;

  /// The product of [harmonics] copies of the spectrum of the last
  /// [fftSize] samples, from [minFrequency] to [maxFrequency] Hz, nothing
  /// under the RMS level [minLevel].
  const HpsPitchAlgorithm({
    this.harmonics = 4,
    this.minFrequency = 50,
    this.maxFrequency = 2000,
    this.fftSize = 4096,
    this.minLevel = 0.004,
  });

  /// The algorithm of a JSON form made by [toJson].
  factory HpsPitchAlgorithm.fromJson(Map<String, Object?> json) =>
      HpsPitchAlgorithm(
        harmonics: (json['harmonics'] as int?) ?? 4,
        minFrequency: _double(json['minFrequency'], 50),
        maxFrequency: _double(json['maxFrequency'], 2000),
        fftSize: (json['fftSize'] as int?) ?? 4096,
        minLevel: _double(json['minLevel'], 0.004),
      );

  @override
  String get type => jsonType;

  @override
  int windowSize(int sampleRate) => fftSize;

  @override
  PitchEstimate? analyze(PitchFrame frame, {PitchStep? step}) {
    var spectrum = frame.spectrum(fftSize);
    if (spectrum.level < minLevel) {
      return null;
    }
    var magnitudes = spectrum.magnitudes;
    var length = magnitudes.length ~/ harmonics;
    var product = Float64List(length);
    for (var i = 0; i < length; i++) {
      var value = magnitudes[i];
      for (var h = 2; h <= harmonics; h++) {
        value *= magnitudes[i * h];
      }
      product[i] = value;
    }
    var bin = spectrum.binHertz;
    var low = (minFrequency / bin).ceil();
    var high = math.min((maxFrequency / bin).floor(), length - 1);
    if (low > high) {
      return null;
    }
    var peak = low;
    for (var i = low + 1; i <= high; i++) {
      if (product[i] > product[peak]) {
        peak = i;
      }
    }
    if (product[peak] == 0) {
      return null;
    }
    var refined = peak.toDouble();
    if (peak > 0 && peak < length - 1) {
      var s0 = product[peak - 1];
      var s1 = product[peak];
      var s2 = product[peak + 1];
      var divisor = 2 * (2 * s1 - s2 - s0);
      if (divisor != 0) {
        refined = peak + (s2 - s0) / divisor;
      }
    }
    var frequency = refined * bin;
    return PitchEstimate(
      frequency,
      clarity: spectrum.harmonicity(frequency, harmonics: harmonics * 2),
      level: spectrum.level,
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'harmonics': harmonics,
    'minFrequency': minFrequency,
    'maxFrequency': maxFrequency,
    'fftSize': fftSize,
    'minLevel': minLevel,
  };
}
