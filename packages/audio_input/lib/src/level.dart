import 'dart:math' as math;
import 'dart:typed_data';

/// [value] (an RMS level or a peak, 1 at full scale) in decibels from full
/// scale; negative infinity for 0.
double audioDecibels(double value) =>
    value <= 0 ? double.negativeInfinity : 20 * math.log(value) / math.ln10;

/// The level of the sound at a moment, for a meter: what came in
/// ([rms], [peak]), what to show ([display], falling slowly like a
/// meter's needle; [heldPeak], kept a moment), whether it clipped.
class AudioLevel {
  /// The RMS level of the last chunk (about 0.71 for a full scale sine).
  final double rms;

  /// The largest absolute sample of the last chunk (1 at full scale).
  final double peak;

  /// The level to show: rises at once, falls slowly.
  final double display;

  /// The highest peak of the last moments.
  final double heldPeak;

  /// True when the sound clipped in the last moments.
  final bool clipped;

  /// The level of a chunk: [rms], [peak], what to show ([display],
  /// [heldPeak]) and whether it [clipped].
  const AudioLevel({
    required this.rms,
    required this.peak,
    required this.display,
    required this.heldPeak,
    this.clipped = false,
  });

  /// Nothing heard.
  static const silence = AudioLevel(rms: 0, peak: 0, display: 0, heldPeak: 0);

  /// [rms] in decibels.
  double get decibels => audioDecibels(rms);

  /// [display] in decibels.
  double get displayDecibels => audioDecibels(display);

  /// [heldPeak] in decibels.
  double get heldPeakDecibels => audioDecibels(heldPeak);

  /// True when the sound is under [decibels] (nothing comes in, or too
  /// far).
  bool quiet({double decibels = -45}) => displayDecibels < decibels;

  @override
  String toString() =>
      'AudioLevel(${displayDecibels.toStringAsFixed(1)} dB, peak '
      '${heldPeakDecibels.toStringAsFixed(1)} dB${clipped ? ', clipped' : ''})';
}

/// Measures chunks of samples for a level meter: the RMS and peak of each
/// chunk, a displayed level falling at [releaseDecibelsPerSecond], the
/// peak held [peakHoldSeconds], clipping (a sample reaching
/// [clipThreshold]) kept [clipHoldSeconds].
class AudioLevelMeter {
  /// The sample rate of the chunks.
  final int sampleRate;

  /// How fast the displayed level falls, in decibels per second.
  final double releaseDecibelsPerSecond;

  /// How long a peak is held, in seconds.
  final double peakHoldSeconds;

  /// How long clipping is shown, in seconds.
  final double clipHoldSeconds;

  /// A sample this loud (absolute) clips.
  final double clipThreshold;

  var _display = 0.0;
  var _heldPeak = 0.0;
  var _peakAge = 0.0;
  var _clipAge = double.infinity;

  /// A meter of chunks at [sampleRate].
  AudioLevelMeter({
    required this.sampleRate,
    this.releaseDecibelsPerSecond = 24,
    this.peakHoldSeconds = 1.5,
    this.clipHoldSeconds = 1,
    this.clipThreshold = 0.99,
  });

  /// The level after [samples].
  AudioLevel add(Float32List samples) {
    var seconds = samples.length / sampleRate;
    var sum = 0.0;
    var peak = 0.0;
    for (var sample in samples) {
      sum += sample * sample;
      var value = sample.abs();
      if (value > peak) {
        peak = value;
      }
    }
    var rms = samples.isEmpty ? 0.0 : math.sqrt(sum / samples.length);
    // Falls at the release rate, rises at once.
    var fallen =
        _display * math.pow(10, -releaseDecibelsPerSecond * seconds / 20);
    _display = math.max(rms, fallen);
    _peakAge += seconds;
    if (peak >= _heldPeak || _peakAge > peakHoldSeconds) {
      _heldPeak = peak;
      _peakAge = 0;
    }
    _clipAge = peak >= clipThreshold ? 0 : _clipAge + seconds;
    return AudioLevel(
      rms: rms,
      peak: peak,
      display: _display,
      heldPeak: _heldPeak,
      clipped: _clipAge <= clipHoldSeconds,
    );
  }

  /// Forgets the past (a new recording).
  void reset() {
    _display = 0;
    _heldPeak = 0;
    _peakAge = 0;
    _clipAge = double.infinity;
  }
}
