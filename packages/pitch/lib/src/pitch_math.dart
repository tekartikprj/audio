import 'dart:math' as math;

/// The frequency in Hz of the MIDI [pitch] (69 is A4, may hold a fraction),
/// [cents] above it, with A4 at [a4] Hz.
double pitchFrequency(num pitch, {double cents = 0, double a4 = 440}) =>
    a4 * math.pow(2, (pitch - 69 + cents / 100) / 12).toDouble();

/// The MIDI pitch of [frequency] in Hz with its fraction (69.2 is A4 20
/// cents sharp), A4 at [a4] Hz.
double pitchOfFrequency(double frequency, {double a4 = 440}) =>
    69 + 12 * math.log(frequency / a4) / math.ln2;

/// The cents from the frequency [from] to the frequency [to] (positive when
/// [to] is higher).
double pitchCents(double from, double to) =>
    1200 * math.log(to / from) / math.ln2;

const _sharpNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];
const _flatNames = [
  'C',
  'Db',
  'D',
  'Eb',
  'E',
  'F',
  'Gb',
  'G',
  'Ab',
  'A',
  'Bb',
  'B',
];

/// The pitch class of the MIDI [pitch]: 0 for C to 11 for B.
int pitchClass(int pitch) => pitch % 12;

/// The octave of the MIDI [pitch] in scientific notation (60 is C4).
int pitchOctave(int pitch) => (pitch ~/ 12) - 1;

/// The name of the MIDI [pitch] with its octave (`A4`, `C#4`, `Db4` when
/// [flats]).
String pitchNoteName(int pitch, {bool flats = false}) =>
    '${(flats ? _flatNames : _sharpNames)[pitchClass(pitch)]}'
    '${pitchOctave(pitch)}';

/// The MIDI pitch of a note [name] with its octave (`A4`, `C#4`, `Db4`,
/// `Bb-1`), null when not a note name.
int? pitchOfNoteName(String name) {
  var match = RegExp(r'^([A-Ga-g])([#b]?)(-?\d+)$').firstMatch(name.trim());
  if (match == null) {
    return null;
  }
  var letter = match.group(1)!.toUpperCase();
  var pitchClass = _sharpNames.indexOf(letter);
  pitchClass += switch (match.group(2)) {
    '#' => 1,
    'b' => -1,
    _ => 0,
  };
  var octave = int.parse(match.group(3)!);
  return (octave + 1) * 12 + pitchClass;
}
