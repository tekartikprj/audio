import 'dart:math' as math;
import 'dart:typed_data';

/// Sounds made by computation, for tests, demos and benches: tones with
/// harmonics, plucked strings, detuned reeds, noise, mixes.
abstract final class PitchSignal {
  /// The harmonic amplitudes of a reed (odd harmonics stronger, falling
  /// about as 1 / n) up to [count] harmonics.
  static List<double> reedHarmonics([int count = 24]) => [
    for (var n = 1; n <= count; n++) (n.isOdd ? 1.0 : 0.5) / math.pow(n, 1.05),
  ];

  /// The harmonic amplitudes of a plucked string.
  static const pluckHarmonics = [1.0, 0.6, 0.4, 0.25, 0.15, 0.1, 0.07, 0.04];

  /// A sine at [frequency] Hz, [seconds] long at [sampleRate], of peak
  /// [amplitude].
  static Float32List sine(
    double frequency, {
    double seconds = 1,
    int sampleRate = 44100,
    double amplitude = 0.3,
  }) => tone(
    frequency,
    seconds: seconds,
    sampleRate: sampleRate,
    harmonics: const [1],
    amplitude: amplitude,
  );

  /// A steady tone at [frequency] Hz, [cents] off, [seconds] long at
  /// [sampleRate]: [harmonics] amplitudes (relative, 1 for the
  /// fundamental), harmonics above 90 % of the Nyquist frequency left out,
  /// scaled to the peak [amplitude] before [tremolo]. The pitch drifts by
  /// [driftCentsPerSecond]; [tremolo] (0 to 1) swells the amplitude at
  /// [tremoloRate] Hz (the bellows, the bow); [phase] (radians) shifts the
  /// start.
  static Float32List tone(
    double frequency, {
    double cents = 0,
    double seconds = 1,
    int sampleRate = 44100,
    List<double>? harmonics,
    double amplitude = 0.3,
    double driftCentsPerSecond = 0,
    double tremolo = 0,
    double tremoloRate = 1.3,
    double phase = 0,
  }) {
    harmonics ??= reedHarmonics();
    var frames = (seconds * sampleRate).round();
    var out = Float64List(frames);
    var base = frequency * math.pow(2, cents / 1200);
    if (driftCentsPerSecond == 0) {
      for (var (index, harmonicAmplitude) in harmonics.indexed) {
        var n = index + 1;
        var f = n * base;
        if (f >= 0.45 * sampleRate || harmonicAmplitude == 0) {
          continue;
        }
        // sin(n·(ωt + phase)) by rotation.
        var step = 2 * math.pi * f / sampleRate;
        var c = math.cos(step);
        var s = math.sin(step);
        var sin = math.sin(n * phase);
        var cos = math.cos(n * phase);
        for (var i = 0; i < frames; i++) {
          out[i] += harmonicAmplitude * sin;
          var next = sin * c + cos * s;
          cos = cos * c - sin * s;
          sin = next;
        }
      }
    } else {
      var angle = phase;
      for (var i = 0; i < frames; i++) {
        var t = i / sampleRate;
        var f = base * math.pow(2, driftCentsPerSecond * t / 1200);
        var sample = 0.0;
        for (var (index, harmonicAmplitude) in harmonics.indexed) {
          var n = index + 1;
          if (n * f < 0.45 * sampleRate) {
            sample += harmonicAmplitude * math.sin(n * angle);
          }
        }
        out[i] = sample;
        angle += 2 * math.pi * f / sampleRate;
      }
    }
    _scale(out, amplitude);
    if (tremolo > 0) {
      for (var i = 0; i < frames; i++) {
        var t = i / sampleRate;
        out[i] *=
            1 -
            tremolo / 2 +
            tremolo / 2 * math.sin(2 * math.pi * tremoloRate * t);
      }
    }
    return Float32List.fromList(out);
  }

  /// A plucked string at [frequency] Hz, [cents] off, [seconds] long at
  /// [sampleRate]: [pluckHarmonics] decaying (the higher ones faster),
  /// scaled to the peak [amplitude], 10 ms fades at both ends.
  static Float32List pluck(
    double frequency, {
    double cents = 0,
    double seconds = 2,
    int sampleRate = 44100,
    double amplitude = 0.8,
    double decay = 1.5,
  }) {
    var frames = (seconds * sampleRate).round();
    var out = Float64List(frames);
    var f = frequency * math.pow(2, cents / 1200);
    for (var (index, harmonicAmplitude) in pluckHarmonics.indexed) {
      var n = index + 1;
      if (n * f >= 0.45 * sampleRate) {
        break;
      }
      var step = 2 * math.pi * n * f / sampleRate;
      var c = math.cos(step);
      var s = math.sin(step);
      var sin = 0.0;
      var cos = 1.0;
      var envelopeStep = math.exp(-decay * n / sampleRate);
      var envelope = 1.0;
      for (var i = 0; i < frames; i++) {
        out[i] += harmonicAmplitude * envelope * sin;
        envelope *= envelopeStep;
        var next = sin * c + cos * s;
        cos = cos * c - sin * s;
        sin = next;
      }
    }
    _scale(out, amplitude);
    var fade = math.min(frames ~/ 2, (0.01 * sampleRate).round());
    for (var i = 0; i < fade; i++) {
      var gain = i / fade;
      out[i] *= gain;
      out[frames - 1 - i] *= gain;
    }
    return Float32List.fromList(out);
  }

  /// Reeds sounding together on [frequency] Hz (an accordion note), each
  /// [cents] off it at its [levels] (1 by default), [seconds] long at
  /// [sampleRate], each with the [harmonics] of a reed, the sum scaled to
  /// the peak [amplitude]; the reeds start out of phase.
  static Float32List reeds(
    double frequency,
    List<double> cents, {
    List<double>? levels,
    double seconds = 1.6,
    int sampleRate = 44100,
    List<double>? harmonics,
    double amplitude = 0.3,
    double driftCentsPerSecond = 0,
    double tremolo = 0,
  }) => mix(
    [
      for (var (index, offset) in cents.indexed)
        tone(
          frequency,
          cents: offset,
          seconds: seconds,
          sampleRate: sampleRate,
          harmonics: harmonics,
          amplitude: 1,
          driftCentsPerSecond: driftCentsPerSecond,
          tremolo: tremolo,
          phase: 2 * math.pi * ((index + 1) * 0.37 % 1),
        ),
    ],
    gains: levels,
    amplitude: amplitude,
  );

  /// The sum of [signals] (the longest one's length), each times its
  /// [gains] (1 by default), scaled to the peak [amplitude] when given.
  static Float32List mix(
    List<Float32List> signals, {
    List<double>? gains,
    double? amplitude,
  }) {
    var length = signals.fold(0, (max, signal) => math.max(max, signal.length));
    var out = Float64List(length);
    for (var (index, signal) in signals.indexed) {
      var gain = gains?[index] ?? 1;
      for (var i = 0; i < signal.length; i++) {
        out[i] += gain * signal[i];
      }
    }
    if (amplitude != null) {
      _scale(out, amplitude);
    }
    return Float32List.fromList(out);
  }

  /// White noise of [length] samples, uniform up to [amplitude], from the
  /// random [seed].
  static Float32List noise(int length, {double amplitude = 0.1, int seed = 1}) {
    var random = math.Random(seed);
    return Float32List.fromList([
      for (var i = 0; i < length; i++)
        amplitude * (random.nextDouble() * 2 - 1),
    ]);
  }

  /// [signal] with white noise up to [amplitude] added (a new list).
  static Float32List withNoise(
    Float32List signal, {
    double amplitude = 0.01,
    int seed = 1,
  }) => mix([signal, noise(signal.length, amplitude: amplitude, seed: seed)]);

  static void _scale(Float64List samples, double amplitude) {
    var peak = 0.0;
    for (var sample in samples) {
      peak = math.max(peak, sample.abs());
    }
    if (peak > 0) {
      var gain = amplitude / peak;
      for (var i = 0; i < samples.length; i++) {
        samples[i] *= gain;
      }
    }
  }
}
