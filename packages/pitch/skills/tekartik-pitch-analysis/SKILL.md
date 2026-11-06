---
name: tekartik-pitch-analysis
description: >-
  Use when detecting pitch in dart with tekartik_pitch: tuners (one note,
  cents), polyphonic detection, tuning instrument strings (PolyTuner,
  PitchTuning presets), accordion reeds (musette cents, beats per second),
  telling whether a note is played over an accompaniment (hearing), running
  several algorithms at once (PitchRunner, PitchAnalysis, PitchStep), JSON
  forms for web workers, smoothing readings, or generating test sounds
  (PitchSignal).
---

# Pitch analysis (tekartik_pitch)

`tekartik_pitch` is pure dart (VM and web, no Flutter): algorithms behind
one interface, a runner applying several of them to the same sound, results
and settings with a JSON form.

## Guidelines

* Depend on it from git:

  ```yaml
  dependencies:
    tekartik_pitch:
      git:
        url: https://github.com/tekartikprj/audio
        path: packages/pitch
  ```

* Two libraries: `package:tekartik_pitch/pitch.dart` (everything) and
  `package:tekartik_pitch/pitch_signal.dart` (`PitchSignal`, computed test
  sounds: `sine`, `tone`, `pluck`, `reeds`, `mix`, `noise`, `withNoise`).
* Samples are mono `Float32List` in [-1, 1]. Feed chunks of any size to a
  `PitchRunner(sampleRate:, analyses: [PitchAnalysis(id, algorithm)], hop:
  2048)`: `add(chunk)` returns the `PitchStep`s due, each ending exactly at
  a multiple of the hop whatever the chunk sizes (a chunk spanning more
  than `maxBehind`, 4, hops gives only its last ones), `bind(stream)` maps
  a stream of chunks.
  Read a result with `step.result<PitchEstimate>('yin')` (null when nothing
  was found or the type differs). `timed: true` fills `step.micros`.
* Each algorithm reads the window it needs from the frame (`windowSize`);
  `PitchFrame.spectrum(size)` is computed once per size and shared, so
  running several spectral algorithms costs one FFT per size.
* Pick the algorithm by question:
  * one note to the cent: `YinPitchAlgorithm` → `PitchEstimate`
    (`frequency`, `clarity`, `level`, `pitch()`, `note()`, `cents()`);
    `AutocorrelationPitchAlgorithm` and `HpsPitchAlgorithm` as alternatives;
  * several notes: `HarmonicPeelingPitchAlgorithm` (`fftSize: 32768` for
    guitar low strings) → `PitchEstimates`;
  * strings of an instrument: `PolyTunerPitchAlgorithm(targets:
    PitchTuning.byId('guitar_standard')!.frequencies())` → `PitchTargets`
    (`cents` per target, sharp positive);
  * is a note played (practice, over an accompaniment):
    `HearingPitchAlgorithm` → `PitchShares.hears(pitch)`;
  * reeds of a held accordion note: `ReedsPitchAlgorithm(source: 'yin')`
    after a YIN analysis id `yin` → `PitchReeds` (`reeds` cents flat to
    sharp, `beats` per pair, `outerBeats`). Needs up to 65536 samples
    (0.4 s at A4, 0.7 s at F3).
* Show results with their quality:
  * steadiness: `PitchSmoother.add` returns a `PitchReading` (`frequency`,
    `spread` in cents, `count`, `held` seconds, `stable()` for a lock
    indicator); `PitchSmootherBank.add(targets, time)` leaves out strings
    that do not sound;
  * confidence: `clarity` (per algorithm, see its doc; YIN above 0.9 is a
    clean note), `spectrum.harmonicity(frequency)` to compare algorithms,
    `PitchReed.uncertainty` (cents) and `support`,
    `PitchReeds.beatUncertainties`, `PitchTarget.level` and `sounds()`,
    `PitchShares.margin(pitch)`;
  * the sound: `PitchStep.decibels`, `peak`, `clipped()` to tell the user
    to come closer or move back;
  * timing: `PitchStep.heardAt(id)` (middle of the analysis window) to
    place a result on a timeline.
* A4: algorithms that use it take `a4`; `runner.setA4(442)` updates them.
* Steady readings with `PitchSmoother` (median + average over a time
  window, `add(frequency, clarity, timeSeconds)`), `PitchSmootherBank` (one
  per target) and `PitchReedsTracker`.
* Where the analyses run: `PitchProcessor.local.open(runner)` gives a
  `PitchSession` (`add`, `steps`, `setAnalyses`, `close`) running here;
  `PitchWorkerProcessor` (tekartik_pitch_web_worker) runs it in a web
  worker or an isolate.
* Web worker or isolate: send `runner.toJson()` (rebuild with
  `PitchRunner.fromJson`), transfer the chunks, send back
  `step.toJson()` (`PitchStep.fromJson`). `pitchAlgorithmFromJson` builds
  an algorithm from its settings; unknown types throw `ArgumentError`.
* Pitch helpers: `pitchFrequency(midi, cents:, a4:)`, `pitchOfFrequency`,
  `pitchCents(from, to)`, `pitchNoteName(midi)` (`A4`, `C#4`),
  `pitchOfNoteName('E2')`.
* In tests, build sounds with `PitchSignal` rather than binary assets.
