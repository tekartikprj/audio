import 'algorithm.dart';
import 'algorithms/autocorrelation.dart';
import 'algorithms/harmonic_peeling.dart';
import 'algorithms/hearing.dart';
import 'algorithms/hps.dart';
import 'algorithms/poly_tuner.dart';
import 'algorithms/reeds.dart';
import 'algorithms/yin.dart';

/// The types of the algorithms [pitchAlgorithmFromJson] knows.
const pitchAlgorithmTypes = [
  YinPitchAlgorithm.jsonType,
  AutocorrelationPitchAlgorithm.jsonType,
  HpsPitchAlgorithm.jsonType,
  HarmonicPeelingPitchAlgorithm.jsonType,
  PolyTunerPitchAlgorithm.jsonType,
  HearingPitchAlgorithm.jsonType,
  ReedsPitchAlgorithm.jsonType,
];

/// The algorithm of a JSON form made by [PitchAlgorithm.toJson] (missing
/// settings take their default); throws an [ArgumentError] for an unknown
/// `type`.
PitchAlgorithm pitchAlgorithmFromJson(Map<String, Object?> json) =>
    switch (json['type']) {
      YinPitchAlgorithm.jsonType => YinPitchAlgorithm.fromJson(json),
      AutocorrelationPitchAlgorithm.jsonType =>
        AutocorrelationPitchAlgorithm.fromJson(json),
      HpsPitchAlgorithm.jsonType => HpsPitchAlgorithm.fromJson(json),
      HarmonicPeelingPitchAlgorithm.jsonType =>
        HarmonicPeelingPitchAlgorithm.fromJson(json),
      PolyTunerPitchAlgorithm.jsonType => PolyTunerPitchAlgorithm.fromJson(
        json,
      ),
      HearingPitchAlgorithm.jsonType => HearingPitchAlgorithm.fromJson(json),
      ReedsPitchAlgorithm.jsonType => ReedsPitchAlgorithm.fromJson(json),
      var type => throw ArgumentError.value(type, 'type', 'unknown'),
    };
