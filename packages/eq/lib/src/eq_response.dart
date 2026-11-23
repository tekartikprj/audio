import 'dart:math';

import 'eq_band.dart';
import 'eq_biquad.dart';

/// The response curve of a preset: the gain in dB at each frequency of a
/// logarithmic grid, for a curve editor or the automatic preamp.
class EqResponse {
  /// The frequencies in Hz, increasing (unmodifiable).
  final List<double> frequencies;

  /// The gain in dB at each of [frequencies] (unmodifiable).
  final List<double> gains;

  EqResponse._(List<double> frequencies, List<double> gains)
    : frequencies = List.unmodifiable(frequencies),
      gains = List.unmodifiable(gains);

  /// The response of [preset] at [sampleRate] Hz on [points] frequencies
  /// spread logarithmically from [minFrequency] to [maxFrequency] Hz (both
  /// included). [includePreamp] false leaves the preamp out (the curve of
  /// the bands alone). Throws an [ArgumentError] when [points] is below 2
  /// or the range is not increasing and positive.
  factory EqResponse.compute(
    EqPreset preset, {
    double sampleRate = 48000,
    int points = 512,
    double minFrequency = 20,
    double maxFrequency = 20000,
    bool includePreamp = true,
  }) {
    if (points < 2) {
      throw ArgumentError.value(points, 'points', 'must be 2 or more');
    }
    if (!(minFrequency > 0) || !(maxFrequency > minFrequency)) {
      throw ArgumentError('Invalid range $minFrequency..$maxFrequency Hz');
    }
    var chain = EqChain.fromPreset(
      includePreamp ? preset : preset.copyWith(preamp: 0),
      sampleRate,
    );
    var frequencies = eqLogFrequencies(points, minFrequency, maxFrequency);
    return EqResponse._(frequencies, [
      for (var frequency in frequencies) chain.gainDbAt(frequency),
    ]);
  }

  /// The highest gain of the curve in dB.
  double get maxGain => gains.reduce(max);

  /// The lowest gain of the curve in dB.
  double get minGain => gains.reduce(min);
}

/// [count] frequencies (2 or more) spread logarithmically from [from] to
/// [to] Hz, both included.
List<double> eqLogFrequencies(int count, double from, double to) {
  var ratio = log(to / from);
  return [
    for (var i = 0; i < count; i++)
      if (i == count - 1) to else from * exp(ratio * i / (count - 1)),
  ];
}

/// The preamp in dB that keeps the bands of [preset] from going above
/// 0 dB: minus the highest gain of their curve (from 20 Hz to 20 kHz, 2048
/// points, at [sampleRate] Hz), or 0 when the curve never goes above 0 dB.
/// The preset's own preamp is not looked at.
double eqAutoPreamp(EqPreset preset, {double sampleRate = 48000}) {
  var response = EqResponse.compute(
    preset,
    sampleRate: sampleRate,
    points: 2048,
    includePreamp: false,
  );
  var highest = response.maxGain;
  return highest > 0 ? -highest : 0;
}
