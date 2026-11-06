import 'package:tekartik_pitch/pitch.dart';
import 'package:test/test.dart';

PitchReeds _reeds(int pitch, List<double> cents, {double uncertainty = 0}) =>
    PitchReeds(
      pitch: pitch,
      reeds: [
        for (var value in cents)
          PitchReed(
            cents: value,
            frequency: pitchFrequency(pitch, cents: value),
            level: 1,
            uncertainty: uncertainty,
          ),
      ],
    );

void main() {
  group('smoother', () {
    test('median, then average, readings forgotten', () {
      var smoother = PitchSmoother(alpha: 0.5);
      expect(smoother.add(null, 0, 0), isNull);
      expect(smoother.add(440, 0.9, 0.1)!.frequency, 440);
      // An octave jump is outvoted.
      expect(smoother.add(880, 0.9, 0.2)!.frequency, 550);
      expect(smoother.add(442, 0.9, 0.3)!.frequency, 496);
      expect(smoother.frequency, 496);
      // Too unclear: not counted, the median stays 442.
      expect(smoother.add(300, 0.1, 0.4)!.frequency, 469);
      // Two seconds later: only the new reading.
      expect(smoother.add(441, 0.9, 2.5)!.frequency, 455);
      expect(smoother.add(null, 0, 4), isNull);
      smoother.add(440, 1, 5);
      smoother.reset();
      expect(smoother.frequency, isNull);
      expect(smoother.reading, isNull);
    });

    test('how steady: spread, count, held, stable', () {
      var smoother = PitchSmoother();
      PitchReading? reading;
      // A4 a little sharp, wobbling ±1 cent, every 50 ms.
      for (var i = 0; i < 10; i++) {
        reading = smoother.add(
          pitchFrequency(69, cents: 5 + (i.isEven ? 1 : -1)),
          0.95,
          i * 0.05,
        );
      }
      expect(reading!.count, 10);
      expect(reading.spread, closeTo(1, 0.05));
      expect(reading.held, closeTo(0.45, 1e-9));
      expect(reading.note(), 69);
      expect(reading.cents(), closeTo(5, 0.5));
      expect(reading.pitch(a4: 442), closeTo(69 - 0.0785 + 0.05, 0.01));
      expect(reading.stable(), isTrue);
      expect(reading.stable(maxSpread: 0.5), isFalse);
      expect(reading.stable(minHeld: 1), isFalse);
      // Another note: held again from its first reading, not stable yet.
      for (var i = 10; i < 30; i++) {
        reading = smoother.add(pitchFrequency(71), 0.95, i * 0.05);
      }
      expect(reading!.note(), 71);
      expect(reading.held, lessThan(0.6));
      expect(reading.toString(), contains('held'));
    });

    test('one per string, silent strings left out', () {
      var bank = PitchSmootherBank(3);
      var targets = const PitchTargets([
        PitchTarget(82.41, 82.5, clarity: 0.9, level: 1),
        PitchTarget(110, null),
        PitchTarget(146.83, 146.9, clarity: 0.9, level: 0.05),
      ]);
      var readings = bank.add(targets, 0);
      expect(readings[0]!.frequency, 82.5);
      expect(readings.skip(1), [null, null]);
      expect(bank.add(null, 2), [null, null, null]);
      bank.reset();
      expect(bank.smoothers.first.frequency, isNull);
    });

    test('reeds: the median of a held note, its uncertainty', () {
      var tracker = PitchReedsTracker(length: 3);
      expect(tracker.current, isNull);
      tracker
        ..add(_reeds(69, [-20, 0, 20], uncertainty: 0.05))
        ..add(_reeds(69, [-30, 1, 19], uncertainty: 0.05));
      var current = tracker.add(_reeds(69, [-19, 2, 21], uncertainty: 0.05))!;
      expect(tracker.count, 3);
      expect(current.reeds.map((reed) => reed.cents), [-20, 1, 20]);
      // The spread over the analyses when larger.
      expect(current.reeds.map((reed) => reed.uncertainty), [1, 1, 1]);
      // Another note: forgotten.
      current = tracker.add(_reeds(70, [0], uncertainty: 0.05))!;
      expect(current.pitch, 70);
      expect(current.reeds.single.cents, 0);
      expect(current.reeds.single.uncertainty, 0.05);
      expect(tracker.add(null), isNull);
      expect(tracker.current, isNull);
      tracker
        ..add(_reeds(70, [0]))
        ..clear();
      expect(tracker.current, isNull);
    });
  });
}
