import 'dart:convert';

import 'package:tekartik_pitch/pitch.dart';
import 'package:test/test.dart';

void main() {
  group('registry', () {
    test('every algorithm, back from json', () {
      var algorithms = <PitchAlgorithm>[
        const YinPitchAlgorithm(threshold: 0.15),
        const AutocorrelationPitchAlgorithm(size: 2048),
        const HpsPitchAlgorithm(harmonics: 3),
        const HarmonicPeelingPitchAlgorithm(maxPitches: 4),
        const PolyTunerPitchAlgorithm(targets: [82.41, 110]),
        const HearingPitchAlgorithm(a4: 442, fftSize: 4096, minSupport: 0.3),
        const ReedsPitchAlgorithm(source: 'yin'),
      ];
      expect(
        algorithms.map((algorithm) => algorithm.type),
        pitchAlgorithmTypes,
      );
      for (var algorithm in algorithms) {
        var json = (jsonDecode(jsonEncode(algorithm.toJson())) as Map)
            .cast<String, Object?>();
        var copy = pitchAlgorithmFromJson(json);
        expect(copy.runtimeType, algorithm.runtimeType);
        expect(copy.toJson(), algorithm.toJson());
        expect(algorithm.toString(), contains(algorithm.type));
      }
    });

    test('defaults, unknown', () {
      for (var type in pitchAlgorithmTypes) {
        if (type == PolyTunerPitchAlgorithm.jsonType) {
          continue;
        }
        expect(pitchAlgorithmFromJson({'type': type}).type, type);
      }
      expect(
        pitchAlgorithmFromJson({
          'type': 'poly_tuner',
          'targets': [440],
        }).windowSize(44100),
        8192,
      );
      expect(() => pitchAlgorithmFromJson({'type': 'x'}), throwsArgumentError);
      expect(const YinPitchAlgorithm().withA4(442), isA<YinPitchAlgorithm>());
    });
  });
}
