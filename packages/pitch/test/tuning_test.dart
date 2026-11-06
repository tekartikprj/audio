import 'package:tekartik_pitch/pitch.dart';
import 'package:test/test.dart';

void main() {
  group('tuning', () {
    test('guitar', () {
      var guitar = PitchTuning.byId('guitar_standard')!;
      expect(guitar.noteNames, ['E2', 'A2', 'D3', 'G3', 'B3', 'E4']);
      var expected = [82.41, 110.00, 146.83, 196.00, 246.94, 329.63];
      for (var (index, frequency) in guitar.frequencies().indexed) {
        expect(frequency, closeTo(expected[index], 0.01));
      }
      expect(guitar.frequencies(a4: 442).last, closeTo(331.13, 0.01));
      expect(PitchTuning.byId('none'), isNull);
    });

    test('all, json', () {
      var ids = {for (var tuning in pitchTunings) tuning.id};
      expect(ids, hasLength(pitchTunings.length));
      expect(PitchTuning.byId('bass_5')!.noteNames.first, 'B0');
      expect(PitchTuning.byId('ukulele')!.noteNames, ['G4', 'C4', 'E4', 'A4']);
      for (var tuning in pitchTunings) {
        expect(PitchTuning.fromJson(tuning.toJson()).toJson(), tuning.toJson());
      }
    });
  });
}
