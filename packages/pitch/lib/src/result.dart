import 'dart:math' as math;

import 'pitch_math.dart';

double _double(Object? value) => (value as num).toDouble();

double? _doubleOrNull(Object? value) => (value as num?)?.toDouble();

/// The result of a pitch algorithm; its JSON form ([toJson],
/// [PitchResult.fromJson]) crosses a worker or isolate boundary.
abstract class PitchResult {
  /// A result.
  const PitchResult();

  /// The kind of result, the `kind` key of its JSON form.
  String get kind;

  /// The JSON form, with its [kind].
  Map<String, Object?> toJson();

  /// The result of a JSON form made by [toJson]; throws an [ArgumentError]
  /// for an unknown kind.
  static PitchResult fromJson(Map<String, Object?> json) =>
      switch (json['kind']) {
        PitchEstimate.jsonKind => PitchEstimate.fromJson(json),
        PitchEstimates.jsonKind => PitchEstimates.fromJson(json),
        PitchTargets.jsonKind => PitchTargets.fromJson(json),
        PitchShares.jsonKind => PitchShares.fromJson(json),
        PitchReeds.jsonKind => PitchReeds.fromJson(json),
        var kind => throw ArgumentError.value(kind, 'kind', 'unknown'),
      };
}

/// A pitch heard: its [frequency], how clear it is ([clarity]) and the
/// [level] of the sound.
///
/// What [clarity] measures depends on the algorithm (see each one); a
/// display keeps the estimates above the threshold its algorithm
/// recommends and steadies them with a `PitchSmoother`.
class PitchEstimate extends PitchResult {
  /// The `kind` of its JSON form.
  static const jsonKind = 'estimate';

  /// The frequency, in Hz.
  final double frequency;

  /// How sure the algorithm is, 0 to 1 (1 for a pure periodic sound).
  final double clarity;

  /// The RMS level of the sound analyzed.
  final double level;

  /// A pitch at [frequency] Hz, [clarity] 0 to 1, [level] the RMS level.
  const PitchEstimate(this.frequency, {this.clarity = 1, this.level = 0});

  /// The estimate of a JSON form made by [toJson].
  factory PitchEstimate.fromJson(Map<String, Object?> json) => PitchEstimate(
    _double(json['frequency']),
    clarity: _double(json['clarity']),
    level: _double(json['level']),
  );

  @override
  String get kind => jsonKind;

  /// The MIDI pitch with its fraction (69.2 is A4 20 cents sharp), A4 at
  /// [a4] Hz.
  double pitch({double a4 = 440}) => pitchOfFrequency(frequency, a4: a4);

  /// The nearest MIDI note, A4 at [a4] Hz.
  int note({double a4 = 440}) => pitch(a4: a4).round();

  /// The cents from the nearest note (-50 to 50), A4 at [a4] Hz.
  double cents({double a4 = 440}) {
    var value = pitch(a4: a4);
    return (value - value.round()) * 100;
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'frequency': frequency,
    'clarity': clarity,
    'level': level,
  };

  @override
  String toString() =>
      'PitchEstimate(${frequency.toStringAsFixed(2)} Hz '
      '${pitchNoteName(note())}, clarity ${clarity.toStringAsFixed(2)})';
}

/// Several pitches heard at once, low to high.
class PitchEstimates extends PitchResult {
  /// The `kind` of its JSON form.
  static const jsonKind = 'estimates';

  /// The pitches, low to high.
  final List<PitchEstimate> estimates;

  /// The [estimates], low to high.
  const PitchEstimates(this.estimates);

  /// The estimates of a JSON form made by [toJson].
  factory PitchEstimates.fromJson(Map<String, Object?> json) => PitchEstimates([
    for (var estimate in json['estimates'] as List)
      PitchEstimate.fromJson((estimate as Map).cast<String, Object?>()),
  ]);

  @override
  String get kind => jsonKind;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'estimates': [for (var estimate in estimates) estimate.toJson()],
  };

  @override
  String toString() => 'PitchEstimates($estimates)';
}

/// How a target (a string of an instrument) is heard.
class PitchTarget {
  /// The frequency aimed at, in Hz.
  final double target;

  /// The frequency found near it, in Hz, null when none.
  final double? frequency;

  /// How clearly the peak stands out of its search window, 0 to 1.
  final double clarity;

  /// How loud it is compared to the loudest target, 0 to 1: a string that
  /// does not sound is low (dim it rather than show its cents).
  final double level;

  /// The [frequency] found for [target] (Hz), [clarity] 0 to 1, [level]
  /// relative to the loudest target.
  const PitchTarget(
    this.target,
    this.frequency, {
    this.clarity = 0,
    this.level = 0,
  });

  /// The target of a JSON form made by [toJson].
  factory PitchTarget.fromJson(Map<String, Object?> json) => PitchTarget(
    _double(json['target']),
    _doubleOrNull(json['frequency']),
    clarity: _double(json['clarity']),
    level: _doubleOrNull(json['level']) ?? 0,
  );

  /// True when a frequency was found.
  bool get found => frequency != null;

  /// True when it sounds: found, at least [minLevel] of the loudest target
  /// and [minClarity] clear.
  bool sounds({double minLevel = 0.1, double minClarity = 0.1}) =>
      found && level >= minLevel && clarity >= minClarity;

  /// The cents from the target to the frequency found (positive when
  /// sharp), null when none.
  double? get cents {
    var frequency = this.frequency;
    return frequency == null ? null : pitchCents(target, frequency);
  }

  /// The JSON form.
  Map<String, Object?> toJson() => {
    'target': target,
    'frequency': frequency,
    'clarity': clarity,
    'level': level,
  };

  @override
  String toString() =>
      'PitchTarget(${target.toStringAsFixed(2)} Hz: '
      '${frequency == null ? 'none' : '${cents!.toStringAsFixed(1)} cents'}'
      ', clarity ${clarity.toStringAsFixed(2)}, '
      'level ${level.toStringAsFixed(2)})';
}

/// The targets of a tuning pass, in the order asked.
class PitchTargets extends PitchResult {
  /// The `kind` of its JSON form.
  static const jsonKind = 'targets';

  /// The targets, in the order asked.
  final List<PitchTarget> targets;

  /// The [targets], in the order asked.
  const PitchTargets(this.targets);

  /// The targets of a JSON form made by [toJson].
  factory PitchTargets.fromJson(Map<String, Object?> json) => PitchTargets([
    for (var target in json['targets'] as List)
      PitchTarget.fromJson((target as Map).cast<String, Object?>()),
  ]);

  @override
  String get kind => jsonKind;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'targets': [for (var target in targets) target.toJson()],
  };

  @override
  String toString() => 'PitchTargets($targets)';
}

/// The share of the sound in the harmonics of each note of a range: is a
/// given note played, other notes sounding too (an accompaniment, the app
/// itself).
class PitchShares extends PitchResult {
  /// The `kind` of its JSON form.
  static const jsonKind = 'shares';

  /// The MIDI pitch of the first share.
  final int firstPitch;

  /// The share (0 to 1) of each pitch from [firstPitch].
  final List<double> shares;

  /// The RMS level of the sound.
  final double level;

  /// The level under which nothing is played.
  final double minLevel;

  /// The share a note played holds at least.
  final double minShare;

  /// The [shares] of the pitches from [firstPitch], [level] the RMS level
  /// of the sound, [minLevel] and [minShare] the thresholds of [hears].
  const PitchShares({
    required this.firstPitch,
    required this.shares,
    required this.level,
    this.minLevel = 0.004,
    this.minShare = 0.2,
  });

  /// The shares of a JSON form made by [toJson].
  factory PitchShares.fromJson(Map<String, Object?> json) => PitchShares(
    firstPitch: json['firstPitch'] as int,
    shares: [for (var share in json['shares'] as List) _double(share)],
    level: _double(json['level']),
    minLevel: _double(json['minLevel']),
    minShare: _double(json['minShare']),
  );

  @override
  String get kind => jsonKind;

  /// The MIDI pitch of the last share.
  int get lastPitch => firstPitch + shares.length - 1;

  /// The share (0 to 1) of the sound in the harmonics of [pitch], 0 out of
  /// the range.
  double share(int pitch) {
    var index = pitch - firstPitch;
    return index < 0 || index >= shares.length ? 0 : shares[index];
  }

  /// How far the share of [pitch] is above those of the notes a semitone
  /// and a tone off (negative when one of them holds more): how clearly it
  /// is played, or how close a wrong note is.
  double margin(int pitch) {
    var neighbors = [
      for (var other in [pitch - 2, pitch - 1, pitch + 1, pitch + 2])
        share(other),
    ].reduce(math.max);
    return share(pitch) - neighbors;
  }

  /// True when [pitch] is played: its share is at least [minShare] and
  /// larger than those of the notes a semitone and a tone off; or the same
  /// an octave off when [octaves] (a register sounding an octave off).
  bool hears(int pitch, {bool octaves = true}) {
    if (level < minLevel) {
      return false;
    }
    if (_hears(pitch)) {
      return true;
    }
    return octaves && (_hears(pitch - 12) || _hears(pitch + 12));
  }

  bool _hears(int pitch) => share(pitch) >= minShare && margin(pitch) > 0;

  /// The pitch with the largest share, null when nothing is played.
  int? get loudest {
    if (level < minLevel || shares.isEmpty) {
      return null;
    }
    var best = 0;
    for (var i = 1; i < shares.length; i++) {
      if (shares[i] > shares[best]) {
        best = i;
      }
    }
    return shares[best] >= minShare ? firstPitch + best : null;
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'firstPitch': firstPitch,
    'shares': shares,
    'level': level,
    'minLevel': minLevel,
    'minShare': minShare,
  };

  @override
  String toString() =>
      'PitchShares(${pitchNoteName(firstPitch)}..${pitchNoteName(lastPitch)}'
      ', level ${level.toStringAsFixed(3)})';
}

/// A reed heard in a note.
class PitchReed {
  /// How far from the note, in cents.
  final double cents;

  /// Its frequency (the fundamental), in Hz.
  final double frequency;

  /// How loud, 1 for the loudest reed of the note.
  final double level;

  /// How precise [cents] is, in cents: the standard error of its readings
  /// on the harmonics (they agree to a few hundredths of a cent on a
  /// steady reed; tenths or more mean noise or a moving pitch).
  final double uncertainty;

  /// The share of the harmonics heard it was found in, 0 to 1 (at least
  /// half for a reed to count; 1 for a clear reed).
  final double support;

  /// A reed [cents] off its note (± [uncertainty] cents), at [frequency]
  /// Hz, [level] relative to the loudest reed, found in [support] of the
  /// harmonics.
  const PitchReed({
    required this.cents,
    required this.frequency,
    required this.level,
    this.uncertainty = 0,
    this.support = 1,
  });

  /// The reed of a JSON form made by [toJson].
  factory PitchReed.fromJson(Map<String, Object?> json) => PitchReed(
    cents: _double(json['cents']),
    frequency: _double(json['frequency']),
    level: _double(json['level']),
    uncertainty: _doubleOrNull(json['uncertainty']) ?? 0,
    support: _doubleOrNull(json['support']) ?? 1,
  );

  /// How precise [frequency] is, in Hz.
  double get frequencyUncertainty =>
      frequency * (math.pow(2, uncertainty / 1200) - 1);

  /// The JSON form.
  Map<String, Object?> toJson() => {
    'cents': cents,
    'frequency': frequency,
    'level': level,
    'uncertainty': uncertainty,
    'support': support,
  };

  @override
  String toString() =>
      'PitchReed(${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)}'
      '±${uncertainty.toStringAsFixed(2)} cents, '
      '${frequency.toStringAsFixed(2)} Hz, level ${level.toStringAsFixed(2)}, '
      'support ${support.toStringAsFixed(2)})';
}

/// The reeds of a held note, flat to sharp (the musette and violin
/// registers of an accordion sound two or three reeds tuned apart).
class PitchReeds extends PitchResult {
  /// The `kind` of its JSON form.
  static const jsonKind = 'reeds';

  /// The MIDI note.
  final int pitch;

  /// The reeds, flat to sharp.
  final List<PitchReed> reeds;

  /// The harmonics heard, the reeds looked for in each.
  final int harmonics;

  /// The samples analyzed.
  final int size;

  /// The [reeds] of the MIDI note [pitch], found among [harmonics]
  /// harmonics of a window of [size] samples.
  const PitchReeds({
    required this.pitch,
    required this.reeds,
    this.harmonics = 0,
    this.size = 0,
  });

  /// The reeds of a JSON form made by [toJson].
  factory PitchReeds.fromJson(Map<String, Object?> json) => PitchReeds(
    pitch: json['pitch'] as int,
    reeds: [
      for (var reed in json['reeds'] as List)
        PitchReed.fromJson((reed as Map).cast<String, Object?>()),
    ],
    harmonics: json['harmonics'] as int,
    size: json['size'] as int,
  );

  @override
  String get kind => jsonKind;

  /// The beats per second of each reed with the next one (one less than
  /// the reeds): the tremolo heard.
  List<double> get beats => [
    for (var i = 0; i + 1 < reeds.length; i++)
      reeds[i + 1].frequency - reeds[i].frequency,
  ];

  /// How precise each of [beats] is, in beats per second.
  List<double> get beatUncertainties => [
    for (var i = 0; i + 1 < reeds.length; i++)
      _beatUncertainty(reeds[i], reeds[i + 1]),
  ];

  static double _beatUncertainty(PitchReed a, PitchReed b) {
    var ua = a.frequencyUncertainty;
    var ub = b.frequencyUncertainty;
    return math.sqrt(ua * ua + ub * ub);
  }

  /// The beats per second of the outer reeds (0 for a single reed).
  double get outerBeats =>
      reeds.length < 2 ? 0 : reeds.last.frequency - reeds.first.frequency;

  /// The spread of the reeds in cents (0 for a single reed).
  double get spread =>
      reeds.length < 2 ? 0 : math.max(0, reeds.last.cents - reeds.first.cents);

  /// The largest [PitchReed.uncertainty] of the reeds, in cents (0 when
  /// none): how far the whole reading can be trusted.
  double get uncertainty =>
      reeds.fold(0.0, (max, reed) => math.max(max, reed.uncertainty));

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'pitch': pitch,
    'reeds': [for (var reed in reeds) reed.toJson()],
    'harmonics': harmonics,
    'size': size,
  };

  @override
  String toString() =>
      'PitchReeds(${pitchNoteName(pitch)}, $reeds, '
      'beats ${[for (var beat in beats) beat.toStringAsFixed(2)]})';
}
