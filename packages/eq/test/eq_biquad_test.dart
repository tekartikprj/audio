import 'dart:math';

import 'package:tekartik_audio_eq/audio_eq.dart';
import 'package:test/test.dart';

void main() {
  const rate = 48000.0;
  double gainAt(EqBand band, double frequency, {double sampleRate = rate}) =>
      EqBiquad.fromBand(band, sampleRate).gainDbAt(frequency, sampleRate);

  group('known points', () {
    test('peaking: its gain at its frequency', () {
      for (var frequency in [30.0, 1000.0, 15000.0]) {
        for (var gain in [-12.0, -3.0, 0.5, 6.0, 18.0]) {
          for (var q in [0.3, 1.0, 4.0]) {
            var band = EqBand.peaking(frequency, gain, q: q);
            expect(
              gainAt(band, frequency),
              closeTo(gain, 1e-9),
              reason: '$band',
            );
          }
        }
      }
    });
    test('peaking: 0 dB far away', () {
      var band = const EqBand.peaking(1000, 9, q: 2);
      expect(gainAt(band, 20), closeTo(0, 0.01));
      expect(gainAt(band, 20000), closeTo(0, 0.05));
    });
    test('passes: -3 dB at the cutoff with the Butterworth Q', () {
      for (var frequency in [50.0, 1000.0, 10000.0]) {
        expect(
          gainAt(EqBand.lowPass(frequency), frequency),
          closeTo(-3.0103, 1e-3),
        );
        expect(
          gainAt(EqBand.highPass(frequency), frequency),
          closeTo(-3.0103, 1e-3),
        );
      }
      expect(gainAt(const EqBand.lowPass(1000), 20), closeTo(0, 1e-3));
      expect(gainAt(const EqBand.highPass(1000), 20000), closeTo(0, 1e-2));
      // 12 dB per octave far from the cutoff (and far from Nyquist, where
      // the bilinear transform makes it steeper).
      expect(
        gainAt(const EqBand.lowPass(250), 2000) -
            gainAt(const EqBand.lowPass(250), 4000),
        closeTo(12, 1.5),
      );
    });
    test('shelves: their gain on the plateau, half of it at the midpoint', () {
      for (var gain in [-9.0, 4.0, 12.0]) {
        var low = EqBand.lowShelf(1000, gain);
        expect(gainAt(low, 20), closeTo(gain, 0.01));
        expect(gainAt(low, 1000), closeTo(gain / 2, 1e-9));
        expect(gainAt(low, 20000), closeTo(0, 0.05));
        var high = EqBand.highShelf(1000, gain);
        expect(gainAt(high, 20), closeTo(0, 0.01));
        expect(gainAt(high, 1000), closeTo(gain / 2, 1e-9));
        expect(gainAt(high, 20000), closeTo(gain, 0.05));
      }
    });
    test('notch, band pass, all pass', () {
      expect(gainAt(const EqBand.notch(1000), 1000), lessThan(-100));
      expect(gainAt(const EqBand.notch(1000), 200), closeTo(0, 0.01));
      expect(gainAt(const EqBand.bandPass(1000, q: 2), 1000), closeTo(0, 1e-9));
      expect(gainAt(const EqBand.bandPass(1000, q: 2), 100), lessThan(-20));
      for (var frequency in [20.0, 500.0, 900.0, 1000.0, 5000.0, 20000.0]) {
        expect(gainAt(const EqBand.allPass(1000), frequency), closeTo(0, 1e-9));
      }
    });
    test('gain ignored by the types without one', () {
      expect(
        EqBiquad.fromBand(
          const EqBand(type: EqFilterType.lowPass, frequency: 1000, gain: 12),
          rate,
        ),
        EqBiquad.fromBand(const EqBand.lowPass(1000), rate),
      );
    });
  });

  test('stable over the whole range', () {
    for (var sampleRate in [44100.0, 48000.0, 96000.0]) {
      for (var type in EqFilterType.values) {
        for (var frequency in eqLogFrequencies(15, 20, 20000)) {
          for (var gain in [-24.0, -6.0, 0.0, 6.0, 24.0]) {
            for (var q in [0.1, 0.5, eqButterworthQ, 2.0, 10.0]) {
              var band = EqBand(
                type: type,
                frequency: frequency,
                gain: gain,
                q: q,
              );
              expect(
                EqBiquad.fromBand(band, sampleRate).isStable,
                isTrue,
                reason: '$band at $sampleRate',
              );
            }
          }
        }
      }
    }
  });

  test('frequency above Nyquist clamped', () {
    var band = const EqBand.peaking(30000, 6);
    var biquad = EqBiquad.fromBand(band, 44100);
    expect(biquad.isStable, isTrue);
    expect(
      biquad,
      EqBiquad.fromBand(band.copyWith(frequency: 0.499 * 44100), 44100),
    );
  });

  test('invalid arguments', () {
    expect(
      () => EqBiquad.fromBand(const EqBand.peaking(0, 6), rate),
      throwsArgumentError,
    );
    expect(
      () => EqBiquad.fromBand(const EqBand.peaking(100, 6, q: 0), rate),
      throwsArgumentError,
    );
    expect(
      () => EqBiquad.fromBand(const EqBand.peaking(100, 6), 0),
      throwsArgumentError,
    );
  });

  test('identity and dB helpers', () {
    expect(EqBiquad.identity.gainDbAt(1234, rate), 0);
    expect(eqDbToLinear(0), 1);
    expect(eqDbToLinear(-6.0206), closeTo(0.5, 1e-5));
    expect(eqLinearToDb(2), closeTo(6.0206, 1e-4));
    expect(eqLinearToDb(eqDbToLinear(-3.7)), closeTo(-3.7, 1e-12));
  });

  test('chain: preamp and bands add up in dB, disabled bands skipped', () {
    var preset = EqPreset(
      preamp: -3,
      bands: const [
        EqBand.peaking(1000, 6),
        EqBand.peaking(1000, 20, enabled: false),
      ],
    );
    var chain = EqChain.fromPreset(preset, rate);
    expect(chain.biquads, hasLength(1));
    expect(chain.gainDbAt(1000), closeTo(3, 1e-9));
    expect(chain.isStable, isTrue);
    expect(chain.preampGain, closeTo(pow(10, -3 / 20), 1e-12));
  });
}
