import 'package:tekartik_pitch/pitch.dart';
import 'package:test/test.dart';

void main() {
  group('pitch math', () {
    test('frequencies', () {
      expect(pitchFrequency(69), 440);
      expect(pitchFrequency(60), closeTo(261.63, 0.01));
      expect(pitchFrequency(40), closeTo(82.41, 0.01));
      expect(pitchFrequency(69, cents: 20), closeTo(445.11, 0.01));
      expect(pitchFrequency(69, a4: 442), 442);
      expect(pitchOfFrequency(440), 69);
      expect(pitchOfFrequency(261.63), closeTo(60, 0.001));
      expect(pitchOfFrequency(442, a4: 442), 69);
    });

    test('cents', () {
      expect(pitchCents(440, 440), 0);
      expect(pitchCents(440, 445), greaterThan(0));
      expect(pitchCents(440, 435), lessThan(0));
      expect(pitchCents(440, 880), closeTo(1200, 1e-9));
    });

    test('names', () {
      expect(pitchNoteName(69), 'A4');
      expect(pitchNoteName(60), 'C4');
      expect(pitchNoteName(61), 'C#4');
      expect(pitchNoteName(61, flats: true), 'Db4');
      expect(pitchNoteName(23), 'B0');
      expect(pitchNoteName(11), 'B-1');
      expect(pitchClass(61), 1);
      expect(pitchOctave(59), 3);
      for (var pitch = 0; pitch < 128; pitch++) {
        expect(pitchOfNoteName(pitchNoteName(pitch)), pitch);
        expect(pitchOfNoteName(pitchNoteName(pitch, flats: true)), pitch);
      }
      expect(pitchOfNoteName('e2'), 40);
      expect(pitchOfNoteName('H2'), isNull);
      expect(pitchOfNoteName(''), isNull);
    });
  });
}
