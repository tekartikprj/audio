import 'dart:math';

import 'eq_band.dart';
import 'eq_biquad.dart';

/// One band as Web Audio plays it: the parameters of a `BiquadFilterNode`
/// ([type] not null), or, when no `BiquadFilterNode` gives the same curve
/// (a shelf whose Q is not the Butterworth one: Web Audio shelves have a
/// fixed slope), the coefficients of an `IIRFilterNode` ([feedforward] and
/// [feedback] not null).
class EqWebAudioFilter {
  /// The `BiquadFilterNode.type` (`peaking`, `lowshelf`, `highshelf`,
  /// `lowpass`, `highpass`, `notch`, `bandpass`, `allpass`), null for an
  /// `IIRFilterNode`.
  final String? type;

  /// The `frequency` in Hz.
  final double frequency;

  /// The `Q` with Web Audio's meaning: in dB for `lowpass` and `highpass`
  /// (`20 log10(Q)`), the plain Q for the others; ignored by the shelves.
  final double q;

  /// The `gain` in dB (peaking and shelves).
  final double gain;

  /// The `feedforward` of an `IIRFilterNode` (`[b0, b1, b2]`), null for a
  /// `BiquadFilterNode`. Fixed for the sample rate it was computed for: a
  /// change needs a new node.
  final List<double>? feedforward;

  /// The `feedback` of an `IIRFilterNode` (`[1, a1, a2]`), null for a
  /// `BiquadFilterNode`.
  final List<double>? feedback;

  const EqWebAudioFilter._({
    required this.type,
    required this.frequency,
    required this.q,
    required this.gain,
    this.feedforward,
    this.feedback,
  });

  /// Whether a `BiquadFilterNode` plays it (its parameters can then change
  /// live); false for an `IIRFilterNode`.
  bool get isBiquadNode => type != null;

  /// The Web Audio form of [band] for an `AudioContext` at [sampleRate] Hz
  /// (used for the `IIRFilterNode` coefficients only).
  factory EqWebAudioFilter.fromBand(EqBand band, double sampleRate) {
    String webType;
    var q = band.q;
    switch (band.type) {
      case EqFilterType.peaking:
        webType = 'peaking';
      case EqFilterType.lowShelf:
      case EqFilterType.highShelf:
        if ((band.q - eqButterworthQ).abs() > 1e-9) {
          var biquad = EqBiquad.fromBand(band, sampleRate);
          return EqWebAudioFilter._(
            type: null,
            frequency: band.frequency,
            q: band.q,
            gain: band.gain,
            feedforward: [biquad.b0, biquad.b1, biquad.b2],
            feedback: [1, biquad.a1, biquad.a2],
          );
        }
        webType = band.type == EqFilterType.lowShelf ? 'lowshelf' : 'highshelf';
      case EqFilterType.lowPass:
        webType = 'lowpass';
        q = 20 * log(band.q) / ln10;
      case EqFilterType.highPass:
        webType = 'highpass';
        q = 20 * log(band.q) / ln10;
      case EqFilterType.notch:
        webType = 'notch';
      case EqFilterType.bandPass:
        webType = 'bandpass';
      case EqFilterType.allPass:
        webType = 'allpass';
    }
    return EqWebAudioFilter._(
      type: webType,
      frequency: band.frequency,
      q: q,
      gain: band.type.hasGain ? band.gain : 0,
    );
  }

  @override
  String toString() => isBiquadNode
      ? 'EqWebAudioFilter($type ${frequency}Hz Q$q ${gain}dB)'
      : 'EqWebAudioFilter(iir $feedforward / $feedback)';
}

/// The Web Audio filters of the enabled bands of [preset], in order, for
/// an `AudioContext` at [sampleRate] Hz; the preamp is a `GainNode` of gain
/// `eqDbToLinear(preset.preamp)` before them.
List<EqWebAudioFilter> eqWebAudioFilters(EqPreset preset, double sampleRate) =>
    [
      for (var band in preset.enabledBands)
        EqWebAudioFilter.fromBand(band, sampleRate),
    ];
