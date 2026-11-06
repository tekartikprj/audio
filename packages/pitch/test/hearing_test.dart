import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:test/test.dart';

const _rate = 44100;

PitchShares _hear(Float32List samples) => const HearingPitchAlgorithm().analyze(
  PitchFrame(samples, sampleRate: _rate),
);

/// [pitch] in the reed registers of an accordion: the reeds of each one,
/// as (octave, cents).
const _registers = {
  'clarinet': [(0, 0.0)],
  'bassoon': [(-1, 0.0)],
  'piccolo': [(1, 0.0)],
  'violin': [(0, 0.0), (0, 9.0)],
  'musette': [(0, 0.0), (0, 19.6), (0, -19.6)],
  'bandoneon': [(-1, 0.0), (0, 0.0)],
  'oboe': [(0, 0.0), (1, 0.0)],
  'master': [(-1, 0.0), (0, 0.0), (0, 12.0), (1, 0.0)],
};

Float32List _note(
  int pitch,
  List<(int, double)> reeds, {
  double seconds = 0.3,
}) => PitchSignal.mix([
  for (var (index, (octave, cents)) in reeds.indexed)
    PitchSignal.tone(
      pitchFrequency(pitch + 12 * octave),
      cents: cents,
      seconds: seconds,
      phase: index * 0.9,
    ),
], amplitude: 0.3);

/// A chord of the left hand: its bass an octave down and its notes.
Float32List _chord(List<int> pitches, {double seconds = 0.3}) =>
    PitchSignal.mix([
      for (var (index, pitch) in pitches.indexed)
        PitchSignal.tone(
          pitchFrequency(pitch),
          seconds: seconds,
          harmonics: PitchSignal.reedHarmonics(12),
          phase: index * 1.3,
        ),
    ], amplitude: 0.3);

String _shares(PitchShares shares, int pitch) => [
  for (var other = pitch - 2; other <= pitch + 2; other++)
    '${pitchNoteName(other)} ${shares.share(other).toStringAsFixed(2)}',
].join(', ');

void main() {
  group('hearing', () {
    test('one note in every register', () {
      for (var MapEntry(key: name, value: reeds) in _registers.entries) {
        for (var pitch in [53, 60, 64, 69, 76, 81]) {
          var shares = _hear(_note(pitch, reeds));
          expect(
            shares.hears(pitch),
            isTrue,
            reason: '$name ${pitchNoteName(pitch)} ${_shares(shares, pitch)}',
          );
          for (var other in [pitch - 1, pitch + 1, pitch + 3, pitch + 4]) {
            expect(
              shares.hears(other),
              isFalse,
              reason:
                  '$name ${pitchNoteName(pitch)} heard as '
                  '${pitchNoteName(other)} ${_shares(shares, other)}',
            );
          }
        }
      }
    });

    test('over the left hand, as loud', () {
      // E G c G | F D B, D | E C over C, G7, C.
      const melody = [64, 67, 72, 67, 65, 62, 59, 62, 64, 60];
      const chords = [
        [48, 52, 55],
        [43, 47, 50, 53],
        [48, 52, 55],
      ];
      var heard = 0;
      var wrong = 0;
      for (var (index, pitch) in melody.indexed) {
        var chord = chords[index < 4 ? 0 : (index < 8 ? 1 : 2)];
        var right = PitchSignal.mix([
          _note(pitch, _registers['clarinet']!),
          _chord(chord),
        ]);
        if (_hear(right).hears(pitch)) {
          heard++;
        }
        // A semitone higher: the expected note is not heard.
        var played = PitchSignal.mix([
          _note(pitch + 1, _registers['clarinet']!),
          _chord(chord),
        ]);
        if (_hear(played).hears(pitch)) {
          wrong++;
        }
      }
      expect(heard / melody.length, greaterThanOrEqualTo(0.8));
      expect(wrong / melody.length, lessThanOrEqualTo(0.1));
    });

    test('silence, noise', () {
      var silent = _hear(Float32List(8192));
      expect(silent.hears(69), isFalse);
      expect(silent.loudest, isNull);
      var noise = _hear(PitchSignal.noise(8192, amplitude: 0.3, seed: 2));
      for (var pitch = 53; pitch <= 81; pitch++) {
        expect(noise.hears(pitch), isFalse, reason: pitchNoteName(pitch));
      }
    });

    test('A4 at 442, the loudest note, the window', () {
      var shares = const HearingPitchAlgorithm(a4: 442).analyze(
        PitchFrame(_note(69, _registers['clarinet']!), sampleRate: _rate),
      );
      expect(shares.hears(69), isTrue);
      expect(shares.loudest, 69);
      expect(shares.firstPitch, 34);
      expect(shares.lastPitch, 98);
      expect(const HearingPitchAlgorithm().windowSize(44100), 8192);
      expect(const HearingPitchAlgorithm().windowSize(16000), 4096);
      expect(const HearingPitchAlgorithm().withA4(442).a4, 442);
    });
  });
}
