import 'dart:math' as math;

import '../algorithm.dart';
import '../frame.dart';
import '../pitch_math.dart';
import '../result.dart';

double _double(Object? value, double defaultValue) =>
    (value as num?)?.toDouble() ?? defaultValue;

/// Which notes are played: the share of the sound in the harmonics of
/// each note of a range ([PitchShares]). A note counts when it holds
/// enough of the sound and more than the notes next to it, so it works
/// over other notes (an accompaniment, the app itself).
class HearingPitchAlgorithm extends PitchAlgorithm<PitchShares> {
  /// The JSON type.
  static const jsonType = 'hearing';

  /// The lowest MIDI pitch heard.
  final int minPitch;

  /// The highest MIDI pitch heard.
  final int maxPitch;

  /// A4, in Hz.
  final double a4;

  /// The harmonics counted.
  final int harmonics;

  /// The lowest frequency counted, in Hz.
  final double minFrequency;

  /// The highest frequency counted, in Hz.
  final double maxFrequency;

  /// The RMS level under which nothing is played.
  final double minLevel;

  /// The share of the sound a note played holds at least.
  final double minShare;

  /// The FFT size, by default 8192 above 24 kHz and 4096 below.
  final int? fftSize;

  /// The share of a note's energy its first two harmonics need; below it,
  /// its share is scaled down: a note borrowing a single partial of
  /// another (C4 from the 3rd harmonic of A4) is not played.
  final double minSupport;

  /// The notes from [minPitch] to [maxPitch], A4 at [a4] Hz, [harmonics]
  /// harmonics counted from [minFrequency] to [maxFrequency] Hz; a note is
  /// played with a share of at least [minShare], nothing under the RMS
  /// level [minLevel]; [fftSize] by default from the sample rate; the
  /// first two harmonics hold at least [minSupport] of a note's energy.
  const HearingPitchAlgorithm({
    this.minPitch = 36,
    this.maxPitch = 96,
    this.a4 = 440,
    this.harmonics = 8,
    this.minFrequency = 60,
    this.maxFrequency = 6000,
    this.minLevel = 0.004,
    this.minShare = 0.2,
    this.fftSize,
    this.minSupport = 0.2,
  });

  /// The algorithm of a JSON form made by [toJson].
  factory HearingPitchAlgorithm.fromJson(Map<String, Object?> json) =>
      HearingPitchAlgorithm(
        minPitch: (json['minPitch'] as int?) ?? 36,
        maxPitch: (json['maxPitch'] as int?) ?? 96,
        a4: _double(json['a4'], 440),
        harmonics: (json['harmonics'] as int?) ?? 8,
        minFrequency: _double(json['minFrequency'], 60),
        maxFrequency: _double(json['maxFrequency'], 6000),
        minLevel: _double(json['minLevel'], 0.004),
        minShare: _double(json['minShare'], 0.2),
        fftSize: json['fftSize'] as int?,
        minSupport: _double(json['minSupport'], 0.2),
      );

  @override
  String get type => jsonType;

  @override
  int windowSize(int sampleRate) =>
      fftSize ?? (sampleRate > 24000 ? 8192 : 4096);

  @override
  HearingPitchAlgorithm withA4(double a4) => HearingPitchAlgorithm(
    minPitch: minPitch,
    maxPitch: maxPitch,
    a4: a4,
    harmonics: harmonics,
    minFrequency: minFrequency,
    maxFrequency: maxFrequency,
    minLevel: minLevel,
    minShare: minShare,
    fftSize: fftSize,
    minSupport: minSupport,
  );

  @override
  PitchShares analyze(PitchFrame frame, {PitchStep? step}) {
    var spectrum = frame.spectrum(windowSize(frame.sampleRate));
    var top = math.min(maxFrequency, spectrum.sampleRate / 2);
    var total = spectrum.energyBetween(minFrequency, top);
    // Two notes more each side: the neighbors compared.
    var first = minPitch - 2;
    var shares = <double>[];
    for (var pitch = first; pitch <= maxPitch + 2; pitch++) {
      if (total <= 0) {
        shares.add(0);
        continue;
      }
      var f0 = pitchFrequency(pitch, a4: a4);
      var energy = 0.0;
      var low = 0.0;
      for (var k = 1; k <= harmonics && k * f0 < top; k++) {
        var frequency = k * f0;
        // A quarter tone each side (reeds tuned apart are 20 cents off),
        // the window of the FFT at least.
        var width = math.max(frequency * 0.0145, 2 * spectrum.binHertz);
        var around = spectrum.energyAround(frequency, width);
        energy += around;
        if (k <= 2) {
          low += around;
        }
      }
      var support = energy <= 0 || minSupport <= 0
          ? 1.0
          : math.min(1.0, low / (minSupport * energy));
      shares.add(math.min(1.0, support * energy / total));
    }
    return PitchShares(
      firstPitch: first,
      shares: shares,
      level: spectrum.level,
      minLevel: minLevel,
      minShare: minShare,
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'minPitch': minPitch,
    'maxPitch': maxPitch,
    'a4': a4,
    'harmonics': harmonics,
    'minFrequency': minFrequency,
    'maxFrequency': maxFrequency,
    'minLevel': minLevel,
    'minShare': minShare,
    if (fftSize != null) 'fftSize': fftSize,
    'minSupport': minSupport,
  };
}
