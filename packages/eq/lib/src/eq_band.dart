import 'dart:math';

/// The Q of a second order Butterworth filter (1/√2, about 0.7071): the
/// default Q of a band, the Q of a low or high pass without resonance.
const eqButterworthQ = 0.7071067811865476;

/// The kind of filter of an [EqBand], each one a second order (biquad)
/// filter of the RBJ Audio EQ Cookbook.
enum EqFilterType {
  /// A bell around [EqBand.frequency]: [EqBand.gain] dB at the frequency,
  /// its width set by [EqBand.q].
  peaking,

  /// [EqBand.gain] dB below [EqBand.frequency], 0 dB above, the frequency
  /// being the midpoint of the slope (half the gain in dB), [EqBand.q] its
  /// steepness.
  lowShelf,

  /// [EqBand.gain] dB above [EqBand.frequency], 0 dB below, the frequency
  /// being the midpoint of the slope.
  highShelf,

  /// Keeps what is below [EqBand.frequency] (-3 dB there with the
  /// Butterworth Q), 12 dB per octave above; no gain.
  lowPass,

  /// Keeps what is above [EqBand.frequency], 12 dB per octave below; no
  /// gain.
  highPass,

  /// Removes a narrow band around [EqBand.frequency], [EqBand.q] its
  /// narrowness; no gain.
  notch,

  /// Keeps a band around [EqBand.frequency] (0 dB at its peak), [EqBand.q]
  /// its narrowness; no gain.
  bandPass,

  /// Changes the phase around [EqBand.frequency], not the level; no gain.
  allPass;

  /// Whether [EqBand.gain] is used by this type (peaking and shelves).
  bool get hasGain => this == peaking || this == lowShelf || this == highShelf;
}

/// One band of an equalizer: a filter [type] at a [frequency] with a [gain]
/// and a [q]. Immutable; [copyWith] gives a changed copy.
class EqBand {
  /// The filter kind.
  final EqFilterType type;

  /// The frequency in Hz: the center of a peaking, notch or band pass band,
  /// the midpoint of a shelf, the cutoff of a low or high pass.
  final double frequency;

  /// The gain in dB (positive boosts); used by peaking and shelf bands only
  /// ([EqFilterType.hasGain]), kept but ignored by the others.
  final double gain;

  /// The quality factor (> 0): larger is narrower (peaking, notch, band
  /// pass) or steeper and more resonant (shelves, passes).
  final double q;

  /// Whether the band is applied; a disabled band is kept in the preset and
  /// skipped by the processor and the response.
  final bool enabled;

  /// A band of any [type]. [gain] defaults to 0 dB, [q] to the Butterworth
  /// Q ([eqButterworthQ]), [enabled] to true.
  const EqBand({
    required this.type,
    required this.frequency,
    this.gain = 0,
    this.q = eqButterworthQ,
    this.enabled = true,
  });

  /// A peaking band: [gain] dB at [frequency] Hz, width [q].
  const EqBand.peaking(
    this.frequency,
    this.gain, {
    this.q = 1,
    this.enabled = true,
  }) : type = EqFilterType.peaking;

  /// A low shelf: [gain] dB below [frequency] Hz (the slope midpoint).
  const EqBand.lowShelf(
    this.frequency,
    this.gain, {
    this.q = eqButterworthQ,
    this.enabled = true,
  }) : type = EqFilterType.lowShelf;

  /// A high shelf: [gain] dB above [frequency] Hz (the slope midpoint).
  const EqBand.highShelf(
    this.frequency,
    this.gain, {
    this.q = eqButterworthQ,
    this.enabled = true,
  }) : type = EqFilterType.highShelf;

  /// A low pass with its cutoff at [frequency] Hz.
  const EqBand.lowPass(
    this.frequency, {
    this.q = eqButterworthQ,
    this.enabled = true,
  }) : type = EqFilterType.lowPass,
       gain = 0;

  /// A high pass with its cutoff at [frequency] Hz.
  const EqBand.highPass(
    this.frequency, {
    this.q = eqButterworthQ,
    this.enabled = true,
  }) : type = EqFilterType.highPass,
       gain = 0;

  /// A notch removing [frequency] Hz, narrowness [q].
  const EqBand.notch(this.frequency, {this.q = 10, this.enabled = true})
    : type = EqFilterType.notch,
      gain = 0;

  /// A band pass keeping [frequency] Hz, narrowness [q].
  const EqBand.bandPass(this.frequency, {this.q = 1, this.enabled = true})
    : type = EqFilterType.bandPass,
      gain = 0;

  /// An all pass centered on [frequency] Hz.
  const EqBand.allPass(
    this.frequency, {
    this.q = eqButterworthQ,
    this.enabled = true,
  }) : type = EqFilterType.allPass,
       gain = 0;

  /// The band read from its [toJson] form; [json] must hold `type` (an
  /// [EqFilterType] name) and `frequency`, the other keys default as in the
  /// constructor. Throws a [FormatException] on a missing or wrong value.
  factory EqBand.fromJson(Map<String, Object?> json) {
    var typeName = json['type'];
    var type = EqFilterType.values.where((t) => t.name == typeName).firstOrNull;
    if (type == null) {
      throw FormatException('Unknown band type', typeName);
    }
    double number(String key, double? defaultValue) {
      var value = json[key];
      if (value == null && defaultValue != null) {
        return defaultValue;
      }
      if (value is num) {
        return value.toDouble();
      }
      throw FormatException('Band $key must be a number', value);
    }

    var enabled = json['enabled'] ?? true;
    if (enabled is! bool) {
      throw FormatException('Band enabled must be a boolean', enabled);
    }
    return EqBand(
      type: type,
      frequency: number('frequency', null),
      gain: number('gain', 0),
      q: number('q', eqButterworthQ),
      enabled: enabled,
    );
  }

  /// The JSON form: `type` (the [EqFilterType] name), `frequency`, `gain`,
  /// `q`, and `enabled` only when false.
  Map<String, Object?> toJson() => {
    'type': type.name,
    'frequency': frequency,
    'gain': gain,
    'q': q,
    if (!enabled) 'enabled': false,
  };

  /// A copy with the given fields replaced.
  EqBand copyWith({
    EqFilterType? type,
    double? frequency,
    double? gain,
    double? q,
    bool? enabled,
  }) => EqBand(
    type: type ?? this.type,
    frequency: frequency ?? this.frequency,
    gain: gain ?? this.gain,
    q: q ?? this.q,
    enabled: enabled ?? this.enabled,
  );

  @override
  bool operator ==(Object other) =>
      other is EqBand &&
      other.type == type &&
      other.frequency == frequency &&
      other.gain == gain &&
      other.q == q &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(type, frequency, gain, q, enabled);

  @override
  String toString() =>
      'EqBand(${type.name} ${frequency}Hz ${gain}dB Q$q${enabled ? '' : ' off'})';
}

/// An equalizer setting: a [preamp] then [bands] in order, with a [name].
/// Immutable.
class EqPreset {
  /// The name shown to the user (may be empty).
  final String name;

  /// The gain in dB applied before the bands (usually negative, to leave
  /// room for the boosts).
  final double preamp;

  /// The bands, applied in this order (unmodifiable).
  final List<EqBand> bands;

  /// A preset of [bands] (copied) after a [preamp] in dB.
  EqPreset({this.name = '', this.preamp = 0, List<EqBand> bands = const []})
    : bands = List.unmodifiable(bands);

  /// A preset doing nothing: no band, 0 dB.
  static final flat = EqPreset(name: 'Flat');

  /// The bands that are applied ([EqBand.enabled]).
  Iterable<EqBand> get enabledBands => bands.where((band) => band.enabled);

  /// The preset read from its [toJson] form. Throws a [FormatException] on a
  /// wrong value.
  factory EqPreset.fromJson(Map<String, Object?> json) {
    var name = json['name'] ?? '';
    var preamp = json['preamp'] ?? 0;
    var bands = json['bands'] ?? const <Object?>[];
    if (name is! String) {
      throw FormatException('Preset name must be a string', name);
    }
    if (preamp is! num) {
      throw FormatException('Preset preamp must be a number', preamp);
    }
    if (bands is! List) {
      throw FormatException('Preset bands must be a list', bands);
    }
    return EqPreset(
      name: name,
      preamp: preamp.toDouble(),
      bands: [
        for (var band in bands)
          if (band is Map<String, Object?>)
            EqBand.fromJson(band)
          else
            throw FormatException('A band must be an object', band),
      ],
    );
  }

  /// The JSON form: `name`, `preamp` and `bands` (each [EqBand.toJson]).
  Map<String, Object?> toJson() => {
    'name': name,
    'preamp': preamp,
    'bands': [for (var band in bands) band.toJson()],
  };

  /// A copy with the given fields replaced.
  EqPreset copyWith({String? name, double? preamp, List<EqBand>? bands}) =>
      EqPreset(
        name: name ?? this.name,
        preamp: preamp ?? this.preamp,
        bands: bands ?? this.bands,
      );

  @override
  bool operator ==(Object other) {
    if (other is! EqPreset ||
        other.name != name ||
        other.preamp != preamp ||
        other.bands.length != bands.length) {
      return false;
    }
    for (var i = 0; i < bands.length; i++) {
      if (other.bands[i] != bands[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(name, preamp, Object.hashAll(bands));

  @override
  String toString() =>
      'EqPreset($name, preamp ${preamp}dB, ${bands.length} bands)';
}

/// Converts a bandwidth in octaves to a Q (the analog relation
/// `Q = √(2^bw) / (2^bw - 1)`): one
/// octave is a Q of about 1.414. [octaves] must be > 0.
double eqBandwidthToQ(double octaves) {
  if (octaves <= 0) {
    throw ArgumentError.value(octaves, 'octaves', 'must be > 0');
  }
  var p = pow(2, octaves).toDouble();
  return sqrt(p) / (p - 1);
}
