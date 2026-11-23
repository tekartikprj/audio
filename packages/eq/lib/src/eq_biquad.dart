import 'dart:math';

import 'eq_band.dart';

/// The coefficients of one second order filter, normalized so that a0 is 1:
/// `y[n] = b0 x[n] + b1 x[n-1] + b2 x[n-2] - a1 y[n-1] - a2 y[n-2]`.
class EqBiquad {
  /// Feed forward coefficient of x[n].
  final double b0;

  /// Feed forward coefficient of x[n-1].
  final double b1;

  /// Feed forward coefficient of x[n-2].
  final double b2;

  /// Feedback coefficient of y[n-1].
  final double a1;

  /// Feedback coefficient of y[n-2].
  final double a2;

  /// A biquad from its normalized coefficients.
  const EqBiquad(this.b0, this.b1, this.b2, this.a1, this.a2);

  /// The filter that changes nothing (b0 = 1, the others 0).
  static const identity = EqBiquad(1, 0, 0, 0, 0);

  /// The coefficients of [band] at [sampleRate] Hz, from the RBJ Audio EQ
  /// Cookbook (the formulas of PipeWire's builtin biquads too).
  ///
  /// The frequency is clamped below the Nyquist frequency (to 0.499 times
  /// [sampleRate]): a band written for 48 kHz still loads at 44.1 kHz. The
  /// [EqBand.enabled] flag is not looked at (the caller skips disabled
  /// bands). Throws an [ArgumentError] when [sampleRate], the frequency or
  /// the Q is not positive.
  factory EqBiquad.fromBand(EqBand band, double sampleRate) {
    if (!(sampleRate > 0)) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'must be > 0');
    }
    if (!(band.frequency > 0)) {
      throw ArgumentError.value(band.frequency, 'frequency', 'must be > 0');
    }
    if (!(band.q > 0)) {
      throw ArgumentError.value(band.q, 'q', 'must be > 0');
    }
    var frequency = min(band.frequency, 0.499 * sampleRate);
    var w0 = 2 * pi * frequency / sampleRate;
    var cosW0 = cos(w0);
    var alpha = sin(w0) / (2 * band.q);
    var a = pow(10, band.gain / 40).toDouble();
    double b0, b1, b2, a0, a1, a2;
    switch (band.type) {
      case EqFilterType.peaking:
        b0 = 1 + alpha * a;
        b1 = -2 * cosW0;
        b2 = 1 - alpha * a;
        a0 = 1 + alpha / a;
        a1 = -2 * cosW0;
        a2 = 1 - alpha / a;
      case EqFilterType.lowShelf:
        var k = 2 * sqrt(a) * alpha;
        b0 = a * ((a + 1) - (a - 1) * cosW0 + k);
        b1 = 2 * a * ((a - 1) - (a + 1) * cosW0);
        b2 = a * ((a + 1) - (a - 1) * cosW0 - k);
        a0 = (a + 1) + (a - 1) * cosW0 + k;
        a1 = -2 * ((a - 1) + (a + 1) * cosW0);
        a2 = (a + 1) + (a - 1) * cosW0 - k;
      case EqFilterType.highShelf:
        var k = 2 * sqrt(a) * alpha;
        b0 = a * ((a + 1) + (a - 1) * cosW0 + k);
        b1 = -2 * a * ((a - 1) + (a + 1) * cosW0);
        b2 = a * ((a + 1) + (a - 1) * cosW0 - k);
        a0 = (a + 1) - (a - 1) * cosW0 + k;
        a1 = 2 * ((a - 1) - (a + 1) * cosW0);
        a2 = (a + 1) - (a - 1) * cosW0 - k;
      case EqFilterType.lowPass:
        b0 = (1 - cosW0) / 2;
        b1 = 1 - cosW0;
        b2 = (1 - cosW0) / 2;
        a0 = 1 + alpha;
        a1 = -2 * cosW0;
        a2 = 1 - alpha;
      case EqFilterType.highPass:
        b0 = (1 + cosW0) / 2;
        b1 = -(1 + cosW0);
        b2 = (1 + cosW0) / 2;
        a0 = 1 + alpha;
        a1 = -2 * cosW0;
        a2 = 1 - alpha;
      case EqFilterType.notch:
        b0 = 1;
        b1 = -2 * cosW0;
        b2 = 1;
        a0 = 1 + alpha;
        a1 = -2 * cosW0;
        a2 = 1 - alpha;
      case EqFilterType.bandPass:
        b0 = alpha;
        b1 = 0;
        b2 = -alpha;
        a0 = 1 + alpha;
        a1 = -2 * cosW0;
        a2 = 1 - alpha;
      case EqFilterType.allPass:
        b0 = 1 - alpha;
        b1 = -2 * cosW0;
        b2 = 1 + alpha;
        a0 = 1 + alpha;
        a1 = -2 * cosW0;
        a2 = 1 - alpha;
    }
    return EqBiquad(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }

  /// Whether both poles are inside the unit circle (the filter does not
  /// blow up): `|a2| < 1` and `|a1| < 1 + a2`.
  bool get isStable => a2.abs() < 1 && a1.abs() < 1 + a2;

  /// The squared magnitude of the response at [frequency] Hz for
  /// [sampleRate] Hz (1 means unchanged).
  double magnitudeSquaredAt(double frequency, double sampleRate) {
    var w = 2 * pi * frequency / sampleRate;
    var cos1 = cos(w);
    var sin1 = sin(w);
    var cos2 = cos(2 * w);
    var sin2 = sin(2 * w);
    // H(e^jw) = (b0 + b1 e^-jw + b2 e^-2jw) / (1 + a1 e^-jw + a2 e^-2jw)
    var numRe = b0 + b1 * cos1 + b2 * cos2;
    var numIm = -(b1 * sin1 + b2 * sin2);
    var denRe = 1 + a1 * cos1 + a2 * cos2;
    var denIm = -(a1 * sin1 + a2 * sin2);
    return (numRe * numRe + numIm * numIm) / (denRe * denRe + denIm * denIm);
  }

  /// The gain in dB of the response at [frequency] Hz for [sampleRate] Hz
  /// (0 means unchanged, minus infinity at a notch's exact frequency).
  double gainDbAt(double frequency, double sampleRate) =>
      10 * log(magnitudeSquaredAt(frequency, sampleRate)) / ln10;

  /// The coefficients as a list `[b0, b1, b2, a1, a2]`.
  List<double> toList() => [b0, b1, b2, a1, a2];

  @override
  bool operator ==(Object other) =>
      other is EqBiquad &&
      other.b0 == b0 &&
      other.b1 == b1 &&
      other.b2 == b2 &&
      other.a1 == a1 &&
      other.a2 == a2;

  @override
  int get hashCode => Object.hash(b0, b1, b2, a1, a2);

  @override
  String toString() => 'EqBiquad(b0 $b0, b1 $b1, b2 $b2, a1 $a1, a2 $a2)';
}

/// Converts a gain in dB to a linear factor (0 dB is 1, -6 dB about 0.5).
double eqDbToLinear(double db) => pow(10, db / 20).toDouble();

/// Converts a linear factor (> 0) to a gain in dB.
double eqLinearToDb(double linear) => 20 * log(linear) / ln10;

/// A preset compiled for one sample rate: the [biquads] of its enabled bands
/// and its preamp as a linear [preampGain].
class EqChain {
  /// The sample rate the coefficients are computed for, in Hz.
  final double sampleRate;

  /// The coefficients of the enabled bands, in order (unmodifiable).
  final List<EqBiquad> biquads;

  /// The preamp as a linear factor (1 for 0 dB).
  final double preampGain;

  /// A chain of [biquads] (copied) after [preampGain].
  EqChain({
    required this.sampleRate,
    List<EqBiquad> biquads = const [],
    this.preampGain = 1,
  }) : biquads = List.unmodifiable(biquads);

  /// The chain of [preset] at [sampleRate] Hz: its enabled bands, its
  /// preamp. Throws an [ArgumentError] on an invalid band (see
  /// [EqBiquad.fromBand]).
  factory EqChain.fromPreset(EqPreset preset, double sampleRate) => EqChain(
    sampleRate: sampleRate,
    biquads: [
      for (var band in preset.enabledBands) EqBiquad.fromBand(band, sampleRate),
    ],
    preampGain: eqDbToLinear(preset.preamp),
  );

  /// The gain in dB of the whole chain (preamp included) at [frequency] Hz.
  double gainDbAt(double frequency) {
    var magnitudeSquared = preampGain * preampGain;
    for (var biquad in biquads) {
      magnitudeSquared *= biquad.magnitudeSquaredAt(frequency, sampleRate);
    }
    return 10 * log(magnitudeSquared) / ln10;
  }

  /// Whether every biquad is stable ([EqBiquad.isStable]).
  bool get isStable => biquads.every((biquad) => biquad.isStable);
}
