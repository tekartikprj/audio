import 'dart:math' as math;
import 'dart:typed_data';

import '../algorithm.dart';
import '../frame.dart';
import '../pitch_math.dart';
import '../result.dart';
import 'yin.dart';

double _double(Object? value, double defaultValue) =>
    (value as num?)?.toDouble() ?? defaultValue;

/// The reeds of a held note: in the musette and violin registers of an
/// accordion two or three reeds sound each note, tuned a few cents apart.
///
/// Each reed is told apart on the harmonics of the note, where the reeds
/// are further apart in Hz (the 4th harmonic of a musette A4 at 435, 440
/// and 445 Hz holds 1740, 1760 and 1780 Hz) while the FFT resolution stays
/// the same; the beats per second come from their frequencies.
///
/// The frequency heard (the middle of the reeds) comes from the
/// [PitchEstimate] of the analysis [source] of the same step, or from YIN
/// when [source] is null. Only the harmonics where reeds [resolution]
/// cents apart are clearly apart are used (the low notes need a longer
/// window, see [sizeFor]); a reed is a peak found at the same cents in at
/// least half of them.
class ReedsPitchAlgorithm extends PitchAlgorithm<PitchReeds> {
  /// The JSON type.
  static const jsonType = 'reeds';

  /// A4, in Hz.
  final double a4;

  /// How far the reeds may be from the frequency heard, in cents.
  final double span;

  /// Reeds this many cents apart are told apart.
  final double resolution;

  /// The highest harmonic frequency used, in Hz.
  final double maxFrequency;

  /// The lowest note expected, in Hz (sets the longest window).
  final double minFrequency;

  /// The RMS level under which nothing is heard.
  final double minLevel;

  /// A peak counts at this share of the strongest one of its harmonic.
  final double minPeak;

  /// A harmonic counts when its strongest peak is this many times its
  /// noise (the median of its band); a peak at half of it.
  final double minClearance;

  /// The id of the analysis giving the frequency heard, YIN when null.
  final String? source;

  /// The clarity the frequency heard needs.
  final double minClarity;

  /// The highest harmonic used (the bands of the next ones would touch).
  static const maxHarmonic = 16;

  /// The smallest window.
  static const minSize = 8192;

  /// The largest window.
  static const maxSize = 65536;

  /// The bins between two reeds for them to be apart (a Hann window).
  static const _binsApart = 3.0;

  static const _yin = YinPitchAlgorithm();

  /// The reeds of the note heard (from [source], else YIN with
  /// [minClarity]), A4 at [a4] Hz, searched [span] cents around it, reeds
  /// [resolution] cents apart told apart, harmonics up to [maxFrequency]
  /// Hz, the window long enough for [minFrequency] Hz; nothing under the
  /// RMS level [minLevel]; a peak counts at [minPeak] of its harmonic's
  /// strongest, a harmonic at [minClearance] times its noise.
  const ReedsPitchAlgorithm({
    this.a4 = 440,
    this.span = 45,
    this.resolution = 8,
    this.maxFrequency = 6000,
    this.minFrequency = 80,
    this.minLevel = 0.004,
    this.minPeak = 0.1,
    this.minClearance = 8,
    this.source,
    this.minClarity = 0.5,
  });

  /// The algorithm of a JSON form made by [toJson].
  factory ReedsPitchAlgorithm.fromJson(Map<String, Object?> json) =>
      ReedsPitchAlgorithm(
        a4: _double(json['a4'], 440),
        span: _double(json['span'], 45),
        resolution: _double(json['resolution'], 8),
        maxFrequency: _double(json['maxFrequency'], 6000),
        minFrequency: _double(json['minFrequency'], 80),
        minLevel: _double(json['minLevel'], 0.004),
        minPeak: _double(json['minPeak'], 0.1),
        minClearance: _double(json['minClearance'], 8),
        source: json['source'] as String?,
        minClarity: _double(json['minClarity'], 0.5),
      );

  @override
  String get type => jsonType;

  @override
  int windowSize(int sampleRate) => math.max(
    sizeFor(minFrequency, sampleRate),
    source == null ? _yin.windowSize(sampleRate) : 0,
  );

  @override
  ReedsPitchAlgorithm withA4(double a4) => ReedsPitchAlgorithm(
    a4: a4,
    span: span,
    resolution: resolution,
    maxFrequency: maxFrequency,
    minFrequency: minFrequency,
    minLevel: minLevel,
    minPeak: minPeak,
    minClearance: minClearance,
    source: source,
    minClarity: minClarity,
  );

  /// Cents of a small frequency step [delta] at [frequency].
  static double _cents(double delta, double frequency) =>
      1200 * math.log(1 + delta / frequency) / math.ln2;

  int _topHarmonic(double frequency, int sampleRate) => math.min(
    maxHarmonic,
    (math.min(maxFrequency, 0.45 * sampleRate) / frequency).floor(),
  );

  /// The first harmonic where reeds [resolution] cents apart are apart
  /// with a window of [size] samples.
  int _firstHarmonic(double frequency, int size, int sampleRate) {
    var bin = sampleRate / size;
    var harmonic = 1;
    while (harmonic < maxHarmonic &&
        _cents(_binsApart * bin, harmonic * frequency) > resolution) {
      harmonic++;
    }
    return harmonic;
  }

  /// The samples analyzed for a note at [frequency] Hz at [sampleRate]:
  /// enough for the reeds to be apart from half of its harmonics up (16384
  /// at A4, 32768 at F3 at 44.1 kHz).
  int sizeFor(double frequency, int sampleRate) {
    var top = _topHarmonic(frequency, sampleRate);
    var size = minSize;
    while (size < maxSize &&
        _firstHarmonic(frequency, size, sampleRate) > math.max(1, top / 2)) {
      size *= 2;
    }
    return size;
  }

  @override
  PitchReeds? analyze(PitchFrame frame, {PitchStep? step}) {
    PitchEstimate? heard;
    var source = this.source;
    if (source != null) {
      heard = step?.result<PitchEstimate>(source);
    } else {
      heard = _yin.analyze(frame);
    }
    if (heard == null || heard.clarity < minClarity) {
      return null;
    }
    return analyzeAt(frame, heard.frequency);
  }

  /// The reeds of the note heard at [frequency] Hz in [frame], null when
  /// nothing is heard.
  PitchReeds? analyzeAt(PitchFrame frame, double frequency) {
    var sampleRate = frame.sampleRate;
    if (frequency <= 0) {
      return null;
    }
    var top = _topHarmonic(frequency, sampleRate);
    if (top < 1) {
      return null;
    }
    var size = sizeFor(frequency, sampleRate);
    var spectrum = frame.spectrum(size);
    if (spectrum.level < minLevel) {
      return null;
    }
    var pitch = pitchOfFrequency(frequency, a4: a4).round();
    var noteFrequency = pitchFrequency(pitch, a4: a4);
    var magnitudes = spectrum.magnitudes;
    var bin = spectrum.binHertz;
    var first = math.min(_firstHarmonic(frequency, size, sampleRate), top);
    var ratio = math.pow(2, span / 1200).toDouble();

    // The peaks of each harmonic, its strongest one.
    var bands = <({double strongest, List<_Peak> peaks})>[];
    for (var harmonic = first; harmonic <= top; harmonic++) {
      var center = harmonic * frequency;
      var low = math.max((center / ratio / bin).ceil(), 1);
      var high = math.min(
        (center * ratio / bin).floor(),
        magnitudes.length - 2,
      );
      if (high <= low) {
        continue;
      }
      var band = Float64List.sublistView(magnitudes, low, high + 1);
      var strongest = band.fold(0.0, math.max);
      // The noise of the band: its median (the peaks of the reeds are
      // narrow, a few bins each).
      var floor = (Float64List.fromList(band)..sort())[band.length ~/ 2];
      if (strongest <= 0 || strongest < minClearance * floor) {
        continue;
      }
      var peaks = <_Peak>[];
      for (var k = low; k <= high; k++) {
        var b = magnitudes[k];
        if (b < minPeak * strongest ||
            b < 0.5 * minClearance * floor ||
            b <= magnitudes[k - 1] ||
            b < magnitudes[k + 1]) {
          continue;
        }
        // Between the bins: a parabola through the log magnitudes (a Hann
        // window peak is close to a gaussian).
        var la = math.log(math.max(magnitudes[k - 1], 1e-12));
        var lb = math.log(b);
        var lc = math.log(math.max(magnitudes[k + 1], 1e-12));
        var divisor = la - 2 * lb + lc;
        var delta = divisor < 0 ? 0.5 * (la - lc) / divisor : 0.0;
        var peakFrequency = (k + delta) * bin;
        var amplitude = math.exp(lb - 0.25 * (la - lc) * delta);
        var cents = pitchCents(harmonic * noteFrequency, peakFrequency);
        peaks.add(_Peak(cents, harmonic, amplitude / strongest));
      }
      bands.add((strongest: strongest, peaks: peaks));
    }
    // The harmonics heard: 40 dB under the strongest one at most.
    var loudest = bands.fold(0.0, (max, band) => math.max(max, band.strongest));
    var heard = [
      for (var band in bands)
        if (band.strongest >= 0.01 * loudest) band,
    ];
    if (heard.isEmpty) {
      return null;
    }

    // The peaks at the same cents in the harmonics: the reeds.
    var peaks = [for (var band in heard) ...band.peaks]
      ..sort((a, b) => a.cents.compareTo(b.cents));
    var clusters = <List<_Peak>>[];
    for (var peak in peaks) {
      var cluster = clusters.lastOrNull;
      if (cluster != null &&
          peak.cents - cluster.first.cents <= resolution / 2) {
        cluster.add(peak);
      } else {
        clusters.add([peak]);
      }
    }
    var votes = math.max(1, (heard.length / 2).ceil());
    var found =
        <({double cents, double level, double uncertainty, double support})>[];
    for (var cluster in clusters) {
      var harmonics = {for (var peak in cluster) peak.harmonic};
      if (harmonics.length < votes) {
        continue;
      }
      var level = 0.0;
      for (var peak in cluster) {
        level += peak.level;
      }
      // A peak between the bins is within about a hundredth of a bin.
      var top = harmonics.reduce(math.max);
      var binCents = _cents(bin, top * frequency);
      found.add((
        cents: _Peak.meanCents(cluster),
        level: level / harmonics.length,
        uncertainty: math.max(
          _Peak.standardError(cluster) ?? 0.1 * binCents,
          0.01 * binCents,
        ),
        support: harmonics.length / heard.length,
      ));
    }
    if (found.isEmpty) {
      return null;
    }
    var loudestReed = found.fold(0.0, (max, reed) => math.max(max, reed.level));
    return PitchReeds(
      pitch: pitch,
      reeds: [
        for (var reed in found)
          PitchReed(
            cents: reed.cents,
            frequency: noteFrequency * math.pow(2, reed.cents / 1200),
            level: reed.level / loudestReed,
            uncertainty: reed.uncertainty,
            support: reed.support,
          ),
      ],
      harmonics: heard.length,
      size: size,
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'a4': a4,
    'span': span,
    'resolution': resolution,
    'maxFrequency': maxFrequency,
    'minFrequency': minFrequency,
    'minLevel': minLevel,
    'minPeak': minPeak,
    'minClearance': minClearance,
    if (source != null) 'source': source,
    'minClarity': minClarity,
  };
}

/// A peak of a harmonic: its cents from the note.
class _Peak {
  final double cents;
  final int harmonic;

  /// Its share of the strongest peak of the harmonic.
  final double level;

  _Peak(this.cents, this.harmonic, this.level);

  /// How much it counts: the high harmonics tell the cents finer.
  double get weight => harmonic * harmonic * level;

  static double meanCents(List<_Peak> peaks) {
    var sum = 0.0;
    var weights = 0.0;
    for (var peak in peaks) {
      sum += peak.cents * peak.weight;
      weights += peak.weight;
    }
    return sum / weights;
  }

  /// The standard error of [meanCents] from the spread of the peaks
  /// (weighted, the effective number of peaks), null under two peaks.
  static double? standardError(List<_Peak> peaks) {
    if (peaks.length < 2) {
      return null;
    }
    var mean = meanCents(peaks);
    var weights = 0.0;
    var squares = 0.0;
    var variance = 0.0;
    for (var peak in peaks) {
      var weight = peak.weight;
      weights += weight;
      squares += weight * weight;
      var delta = peak.cents - mean;
      variance += weight * delta * delta;
    }
    if (weights <= 0 || squares <= 0) {
      return null;
    }
    variance /= weights;
    var effective = weights * weights / squares;
    return math.sqrt(variance / math.max(1, effective - 1));
  }
}
