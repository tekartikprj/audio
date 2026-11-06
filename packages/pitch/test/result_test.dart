import 'dart:convert';

import 'package:tekartik_pitch/pitch.dart';
import 'package:test/test.dart';

PitchResult _roundTrip(PitchResult result) => PitchResult.fromJson(
  (jsonDecode(jsonEncode(result.toJson())) as Map).cast<String, Object?>(),
);

void main() {
  group('results', () {
    test('json round trips', () {
      var results = <PitchResult>[
        const PitchEstimate(440.5, clarity: 0.9, level: 0.1),
        const PitchEstimates([PitchEstimate(110), PitchEstimate(220)]),
        const PitchTargets([PitchTarget(440, 441, clarity: 0.5)]),
        const PitchTargets([PitchTarget(440, null)]),
        const PitchShares(firstPitch: 60, shares: [0.1, 0.5], level: 0.2),
        const PitchReeds(
          pitch: 69,
          reeds: [PitchReed(cents: -20, frequency: 435, level: 1)],
          harmonics: 10,
          size: 16384,
        ),
      ];
      for (var result in results) {
        expect(_roundTrip(result).toJson(), result.toJson());
        expect(result.toString(), isNotEmpty);
      }
      expect(() => PitchResult.fromJson({'kind': 'none'}), throwsArgumentError);
    });

    test('estimate', () {
      var estimate = PitchEstimate(pitchFrequency(69, cents: -12));
      expect(estimate.note(), 69);
      expect(estimate.cents(), closeTo(-12, 1e-9));
      expect(estimate.pitch(), closeTo(68.88, 1e-9));
    });

    test('targets', () {
      var target = PitchTarget(440, pitchFrequency(69, cents: 7));
      expect(target.found, isTrue);
      expect(target.cents, closeTo(7, 1e-9));
      expect(const PitchTarget(440, null).cents, isNull);
    });

    test('shares: a note, its neighbors, its octave', () {
      PitchShares shares(Map<int, double> values, {double level = 0.1}) =>
          PitchShares(
            firstPitch: 60,
            shares: [for (var p = 60; p <= 84; p++) values[p] ?? 0],
            level: level,
          );
      var a = shares({69: 0.6, 70: 0.1});
      expect(a.hears(69), isTrue);
      expect(a.hears(70), isFalse);
      expect(a.hears(81), isTrue);
      expect(a.hears(81, octaves: false), isFalse);
      expect(a.loudest, 69);
      expect(a.share(10), 0);
      // A neighbor holding more.
      expect(shares({69: 0.3, 71: 0.4}).hears(69), isFalse);
      // Too quiet.
      expect(shares({69: 0.6}, level: 0.001).hears(69), isFalse);
      expect(shares({69: 0.1}).loudest, isNull);
    });

    test('reeds', () {
      const reeds = PitchReeds(
        pitch: 69,
        reeds: [
          PitchReed(cents: -19.6, frequency: 435.05, level: 1),
          PitchReed(cents: 0, frequency: 440, level: 1),
          PitchReed(cents: 19.6, frequency: 445.01, level: 1),
        ],
      );
      expect(reeds.beats[0], closeTo(4.95, 1e-9));
      expect(reeds.beats[1], closeTo(5.01, 1e-9));
      expect(reeds.outerBeats, closeTo(9.96, 1e-9));
      expect(reeds.spread, closeTo(39.2, 1e-9));
    });

    test('quality fields: margin, sounds, uncertainties', () {
      var shares = const PitchShares(
        firstPitch: 60,
        shares: [0, 0.1, 0, 0, 0, 0, 0, 0, 0.4, 0.05, 0.5, 0.1, 0],
        level: 0.1,
      );
      expect(shares.margin(70), closeTo(0.1, 1e-9));
      expect(shares.margin(68), closeTo(-0.1, 1e-9));
      const target = PitchTarget(440, 441, clarity: 0.8, level: 0.5);
      expect(target.sounds(), isTrue);
      expect(target.sounds(minLevel: 0.6), isFalse);
      expect(target.sounds(minClarity: 0.9), isFalse);
      expect(const PitchTarget(440, null, level: 1).sounds(), isFalse);
      const reed = PitchReed(
        cents: 0,
        frequency: 440,
        level: 1,
        uncertainty: 1,
        support: 0.75,
      );
      expect(reed.frequencyUncertainty, closeTo(0.254, 0.001));
      expect(PitchReed.fromJson(reed.toJson()).toJson(), reed.toJson());
      // Older forms: defaults.
      var old = PitchReed.fromJson({'cents': 1, 'frequency': 440, 'level': 1});
      expect(old.uncertainty, 0);
      expect(old.support, 1);
      expect(PitchTarget.fromJson({'target': 440, 'clarity': 0}).level, 0);
    });
  });
}
