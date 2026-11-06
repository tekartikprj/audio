# tekartik_pitch

Pitch analysis in pure Dart (VM and web): one note to the cent, several
notes at once, tuning against targets (the strings of an instrument), the
reeds of an accordion note, which notes are played; several algorithms run
at once on the same sound, sharing their FFTs.

## Setup

```yaml
dependencies:
  tekartik_pitch:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages/pitch
```

## Usage

```dart
import 'package:tekartik_pitch/pitch.dart';

var runner = PitchRunner(
  sampleRate: 44100,
  analyses: const [
    PitchAnalysis('yin', YinPitchAlgorithm()),
    PitchAnalysis('reeds', ReedsPitchAlgorithm(source: 'yin')),
  ],
);
// Chunks of any size (a microphone, a file), a step at every multiple of
// 2048 samples.
for (var step in runner.add(chunk)) {
  var note = step.result<PitchEstimate>('yin');
  var reeds = step.result<PitchReeds>('reeds');
}
```

| Algorithm | Result | |
|---|---|---|
| `YinPitchAlgorithm` | `PitchEstimate` | One note to the cent (YIN by FFT) |
| `AutocorrelationPitchAlgorithm` | `PitchEstimate` | One note, autocorrelation |
| `HpsPitchAlgorithm` | `PitchEstimate` | One note, harmonic product spectrum |
| `HarmonicPeelingPitchAlgorithm` | `PitchEstimates` | Several notes, spectral peeling |
| `PolyTunerPitchAlgorithm` | `PitchTargets` | Cents of each target frequency |
| `HearingPitchAlgorithm` | `PitchShares` | Is a given note played, over other notes |
| `ReedsPitchAlgorithm` | `PitchReeds` | Cents of each reed of a held note, beats per second |

Algorithms, runner settings and results have a JSON form
(`pitchAlgorithmFromJson`, `PitchRunner.fromJson`, `PitchResult.fromJson`)
to cross a web worker or isolate boundary. `PitchSmoother`,
`PitchSmootherBank` and `PitchReedsTracker` steady the readings;
`pitchTunings` holds instrument tunings. `package:tekartik_pitch/pitch_signal.dart`
computes test sounds (tones, plucked strings, detuned reeds, noise).

## Showing a result well

What a display needs besides the value:

- **Is it steady?** `PitchSmoother.add(frequency, clarity, time)` returns a
  `PitchReading`: the steadied `frequency`, the `spread` of the readings in
  cents, their `count`, how long the note is `held`, and `stable()` (a lock
  indicator).
- **How sure?** `clarity` per estimate (its meaning is documented on each
  algorithm), `PitchSpectrum.harmonicity(frequency)` to compare any
  estimate the same way; per reed `uncertainty` (cents, how much the
  harmonics disagree) and `support`, `PitchReeds.beatUncertainties`; per
  string `level` and `PitchTarget.sounds()`; `PitchShares.margin(pitch)`
  for a note almost played.
- **Is the sound right?** `PitchStep.decibels`, `peak` and `clipped()` (too
  quiet, too loud).
- **When was it heard?** `PitchStep.windows` and `heardAt(id)`: the middle
  of the samples an analysis looked at.

See [the plan](../../doc/pitch_plan.md).
