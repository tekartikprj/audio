import 'dart:typed_data';

import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:tekartik_pitch_flutter/pitch_flutter.dart';

/// A test sound of the lab, computed (it loops).
class LabSound {
  /// The id.
  final String id;

  /// The name shown.
  final String name;

  /// Computes the samples at a sample rate.
  final Float32List Function(int sampleRate) build;

  /// The test sound [id] named [name], computed by [build].
  const LabSound(this.id, this.name, this.build);
}

const _guitarDetune = [-18.0, 10.0, -12.0, 22.0, -8.0, 17.0];

/// The test sounds.
final labSounds = <LabSound>[
  LabSound(
    'musette_a4',
    'Accordion musette A4 (435, 440, 445 Hz)',
    (rate) =>
        PitchSignal.reeds(440, [-19.6, 0, 19.6], seconds: 4, sampleRate: rate),
  ),
  LabSound(
    'musette_d4_uneven',
    'Musette D4, uneven (−14, +3, +24 cents)',
    (rate) => PitchSignal.reeds(
      pitchFrequency(62),
      [-14, 3, 24],
      levels: [0.5, 1, 0.8],
      seconds: 4,
      sampleRate: rate,
    ),
  ),
  LabSound(
    'violin_e5',
    'Accordion violin E5 (0 and +9 cents)',
    (rate) => PitchSignal.reeds(
      pitchFrequency(76),
      [0, 9],
      seconds: 4,
      sampleRate: rate,
    ),
  ),
  LabSound(
    'reed_g4_sharp',
    'One reed G4, 6 cents sharp',
    (rate) => PitchSignal.tone(
      pitchFrequency(67),
      cents: 6,
      seconds: 2,
      sampleRate: rate,
    ),
  ),
  LabSound(
    'guitar_chord',
    'Guitar, the six strings out of tune',
    (rate) => PitchSignal.mix([
      for (var (index, frequency) in PitchTuning.byId(
        'guitar_standard',
      )!.frequencies().indexed)
        PitchSignal.pluck(
          frequency,
          cents: _guitarDetune[index],
          seconds: 3,
          sampleRate: rate,
        ),
    ], amplitude: 0.8),
  ),
  LabSound(
    'guitar_e2',
    'Guitar low E, 8 cents flat',
    (rate) => PitchSignal.pluck(
      pitchFrequency(40),
      cents: -8,
      seconds: 3,
      sampleRate: rate,
    ),
  ),
  LabSound(
    'sine_a4',
    'Sine A4',
    (rate) => PitchSignal.sine(440, seconds: 2, sampleRate: rate),
  ),
  LabSound(
    'noisy_a4',
    'A4 in noise',
    (rate) => PitchSignal.withNoise(
      PitchSignal.tone(440, seconds: 2, sampleRate: rate),
      amplitude: 0.15,
    ),
  ),
  LabSound(
    'noise',
    'White noise',
    (rate) => PitchSignal.noise(rate * 2, amplitude: 0.2),
  ),
];
