import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';

/// The largest absolute value of [samples] (1 at full scale), 0 when
/// empty.
double pitchPeak(Float32List samples) {
  var peak = 0.0;
  for (var sample in samples) {
    var value = sample.abs();
    if (value > peak) {
      peak = value;
    }
  }
  return peak;
}

/// The RMS [level] in decibels from full scale (0 for 1, -20 for 0.1,
/// negative infinity for 0).
double pitchDecibels(double level) =>
    level <= 0 ? double.negativeInfinity : 20 * math.log(level) / math.ln10;

/// The RMS level of [samples] (about 0.71 for a full scale sine), 0 when
/// empty.
double pitchLevel(Float32List samples) {
  if (samples.isEmpty) {
    return 0;
  }
  var sum = 0.0;
  for (var sample in samples) {
    sum += sample * sample;
  }
  return math.sqrt(sum / samples.length);
}

/// The magnitude spectrum of the last samples of a frame, Hann windowed.
class PitchSpectrum {
  /// The sample rate of the samples.
  final int sampleRate;

  /// The FFT size (a power of two).
  final int size;

  /// The magnitude of each bin, from 0 Hz to half the sample rate
  /// ([size] / 2 + 1 bins).
  final Float64List magnitudes;

  /// The RMS level of the samples analyzed.
  final double level;

  PitchSpectrum._(this.sampleRate, this.size, this.magnitudes, this.level);

  /// The spectrum of the last [size] samples of [samples] at [sampleRate]
  /// (zeros before them when fewer), [size] a power of two.
  factory PitchSpectrum.of(
    Float32List samples, {
    required int sampleRate,
    required int size,
  }) {
    var fft = PitchFft(size);
    var re = Float64List(size);
    var im = Float64List(size);
    var n = math.min(samples.length, size);
    var offset = samples.length - n;
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      var sample = samples[offset + i];
      sum += sample * sample;
      var hann = n < 2 ? 1.0 : 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
      re[size - n + i] = sample * hann;
    }
    fft.transform(re, im);
    var magnitudes = Float64List(size ~/ 2 + 1);
    for (var i = 0; i < magnitudes.length; i++) {
      magnitudes[i] = math.sqrt(re[i] * re[i] + im[i] * im[i]);
    }
    return PitchSpectrum._(
      sampleRate,
      size,
      magnitudes,
      n == 0 ? 0 : math.sqrt(sum / n),
    );
  }

  /// The width of a bin, in Hz.
  double get binHertz => sampleRate / size;

  /// The energy (sum of squared magnitudes) of the bins within [width] Hz
  /// of [frequency].
  double energyAround(double frequency, double width) =>
      energyBetween(frequency - width, frequency + width);

  /// The energy (sum of squared magnitudes) of the bins from [low] to
  /// [high] Hz.
  double energyBetween(double low, double high) {
    var from = math.max((low / binHertz).floor(), 0);
    var to = math.min((high / binHertz).ceil(), magnitudes.length - 1);
    var energy = 0.0;
    for (var i = from; i <= to; i++) {
      energy += magnitudes[i] * magnitudes[i];
    }
    return energy;
  }

  /// The share (0 to 1) of the energy from [minFrequency] to
  /// [maxFrequency] Hz lying within [cents] (and 2 bins at least) of the
  /// first [harmonics] harmonics of [frequency]: about 1 for a clean note,
  /// low for noise or another note. Comparable across algorithms: a
  /// display can rank or filter any estimate with it.
  double harmonicity(
    double frequency, {
    int harmonics = 8,
    double cents = 25,
    double minFrequency = 50,
    double maxFrequency = 6000,
  }) {
    var top = math.min(maxFrequency, sampleRate / 2);
    var total = energyBetween(minFrequency, top);
    if (total <= 0 || frequency <= 0) {
      return 0;
    }
    var ratio = math.pow(2, cents / 1200) - 1;
    var energy = 0.0;
    for (var k = 1; k <= harmonics && k * frequency < top; k++) {
      var center = k * frequency;
      var width = math.max(center * ratio, 2 * binHertz);
      energy += energyBetween(
        math.max(center - width, minFrequency),
        math.min(center + width, top),
      );
    }
    return math.min(1, energy / total);
  }
}

/// The latest samples given to the algorithms of a step, with their
/// spectra computed once per FFT size and shared.
class PitchFrame {
  /// The samples, oldest first (zeros before the first sample heard).
  final Float32List samples;

  /// Their sample rate.
  final int sampleRate;

  final _spectra = <int, PitchSpectrum>{};

  /// A frame of [samples] at [sampleRate].
  PitchFrame(this.samples, {required this.sampleRate});

  /// The number of samples.
  int get length => samples.length;

  /// The last [count] samples: a view when there are enough, else a copy
  /// with zeros before.
  Float32List latest(int count) {
    if (count <= samples.length) {
      return Float32List.sublistView(samples, samples.length - count);
    }
    return Float32List(count)..setRange(count - samples.length, count, samples);
  }

  /// The RMS level of the last [count] samples (all of them when null).
  double level([int? count]) => pitchLevel(latest(count ?? samples.length));

  /// The spectrum of the last [size] samples ([size] a power of two),
  /// computed once.
  PitchSpectrum spectrum(int size) => _spectra.putIfAbsent(
    size,
    () => PitchSpectrum.of(samples, sampleRate: sampleRate, size: size),
  );
}
