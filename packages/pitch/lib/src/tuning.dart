import 'pitch_math.dart';

/// The tuning of an instrument: the MIDI pitch of each string, low string
/// first (or in playing order for re-entrant tunings such as the ukulele).
class PitchTuning {
  /// The id (`guitar_standard`).
  final String id;

  /// The name shown (`Guitar, standard (E A D G B E)`).
  final String name;

  /// The MIDI pitch of each string.
  final List<int> pitches;

  /// The tuning [id] named [name], its strings at [pitches].
  const PitchTuning(this.id, this.name, this.pitches);

  /// The tuning of a JSON form made by [toJson].
  factory PitchTuning.fromJson(Map<String, Object?> json) => PitchTuning(
    json['id'] as String,
    json['name'] as String,
    (json['pitches'] as List).cast<int>(),
  );

  /// The built-in tuning [id], null when unknown.
  static PitchTuning? byId(String id) =>
      pitchTunings.where((tuning) => tuning.id == id).firstOrNull;

  /// The frequency of each string in Hz, A4 at [a4] Hz.
  List<double> frequencies({double a4 = 440}) => [
    for (var pitch in pitches) pitchFrequency(pitch, a4: a4),
  ];

  /// The name of each string (`E2`).
  List<String> get noteNames => [
    for (var pitch in pitches) pitchNoteName(pitch),
  ];

  /// The JSON form.
  Map<String, Object?> toJson() => {'id': id, 'name': name, 'pitches': pitches};

  @override
  String toString() => 'PitchTuning($id, ${noteNames.join(' ')})';
}

/// The built-in tunings.
const pitchTunings = <PitchTuning>[
  PitchTuning('guitar_standard', 'Guitar, standard (E A D G B E)', [
    40,
    45,
    50,
    55,
    59,
    64,
  ]),
  PitchTuning('guitar_drop_d', 'Guitar, drop D (D A D G B E)', [
    38,
    45,
    50,
    55,
    59,
    64,
  ]),
  PitchTuning('guitar_dadgad', 'Guitar, DADGAD', [38, 45, 50, 55, 57, 62]),
  PitchTuning('guitar_open_g', 'Guitar, open G (D G D G B D)', [
    38,
    43,
    50,
    55,
    59,
    62,
  ]),
  PitchTuning('bass_4', 'Bass, 4 strings (E A D G)', [28, 33, 38, 43]),
  PitchTuning('bass_5', 'Bass, 5 strings (B E A D G)', [23, 28, 33, 38, 43]),
  PitchTuning('ukulele', 'Ukulele (G C E A)', [67, 60, 64, 69]),
  PitchTuning('violin', 'Violin (G D A E)', [55, 62, 69, 76]),
  PitchTuning('viola', 'Viola (C G D A)', [48, 55, 62, 69]),
  PitchTuning('cello', 'Cello (C G D A)', [36, 43, 50, 57]),
  PitchTuning('mandolin', 'Mandolin (G D A E)', [55, 62, 69, 76]),
  PitchTuning('banjo_5', 'Banjo, 5 strings (G D G B D)', [67, 50, 55, 59, 62]),
];
