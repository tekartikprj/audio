# Pitch packages: plan

Status: steps 1 and 2 committed (84eae60, 5bef0cf, 2026-11-06); step 3 (the
web worker) and the lab (step 4) done, a demo on tkhostelio dev.

## Goal

One home for pitch analysis in Dart, shared by the tuners and the music
apps built on it:

- any algorithm behind a common interface (single note, several notes,
  tuning against targets, the reeds of a note, which notes are played);
- several algorithms run at once on the same sound, sharing their FFTs, to
  compare them live or in tests;
- poly tuning (each string of a guitar, each reed of an accordion note);
- the microphone and recorded files as interchangeable inputs, their level
  shown on its own (a direct sign the sound comes in);
- on the web, the analysis in a web worker; on native, in an isolate;
- the Flutter parts (listening state, gauges, displays) reusable by apps
  with their own look.

The code comes from earlier private experiments (a polyphonic guitar tuner,
an accordion learning app, a chromatic pitch display): textbook algorithms
written from scratch, gathered and cleaned up here.

## Packages

In this repository, next to `tekartik_wav`, as in `tekartikprj/music`:
`packages/` for pure Dart, `packages_flutter/` for Flutter, `apps/` for the
showcase.

| Package | Kind | Content |
|---|---|---|
| `tekartik_pitch` (`packages/pitch`) | pure Dart (VM, web) | Frames with a shared spectrum per FFT size, the algorithms, their results (JSON), the runner of several algorithms at once, quality for display, smoothers, instrument tunings, test signals |
| `tekartik_audio_input` (`packages/audio_input`) | pure Dart | `AudioInput` (sample rate, latency, `start()` → `Stream<Float32List>`, `stop()`), its states and errors, input devices, a push input (tests), a samples or WAV input played in real time or faster (`tekartik_wav`), PCM16 decoding, the level of the sound (`AudioLevelMeter`) and any input measured as it goes (`AudioInputMetered`) |
| `tekartik_pitch_web_worker` (`packages/pitch_web_worker`) | pure Dart, web + io | The runner in a web worker (`tekartik_web_worker_build`), in an isolate on io, on the main thread as a fallback |
| `tekartik_audio_input_flutter` (`packages_flutter/audio_input_flutter`) | Flutter, no plugin | Level widgets: a bar with peak hold and clipping, a microphone icon pulsing with the sound, a builder following a metered input |
| `tekartik_audio_input_record` (`packages_flutter/audio_input_record`) | Flutter plugin | The microphone through the `record` package: 16 bit PCM to floats, no automatic gain, echo cancellation or noise suppression (they eat held notes), permission and failure errors, input devices. Kept apart so apps without a microphone do not carry the plugin (iOS asks for a microphone purpose string as soon as the API is linked) |
| `tekartik_pitch_flutter` (`packages_flutter/pitch_flutter`) | Flutter, no plugin | A listening controller (`ValueNotifier`s: state, level, step; no state management package), widgets: start/stop control, needle gauge, per string display, reeds view; colors from the theme |
| `pitch_lab` (`apps/pitch_lab`) | Flutter app | Microphone or WAV file, several algorithms side by side (comparison view), mono / poly / reeds, instruments |

## `tekartik_pitch` design

- **Chunks, not frames.** Inputs give chunks of any size (`Float32List`).
  The runner keeps the last samples in a ring and, at every multiple of the
  hop (whatever the chunk sizes), hands each algorithm a `PitchFrame` of
  the latest samples: each algorithm reads the window it needs (YIN 2048 to
  4096, the reeds 16384 to 65536), which fixed frames cannot do. A chunk
  spanning more than `maxBehind` hops (a busy page) gives only its last
  steps. `Float32List` chunks are transferable to a web worker.
- **Shared spectra.** `PitchFrame.spectrum(size)` is computed once per size
  (Hann window) and shared by the algorithms of the step.
- **Algorithms** (`PitchAlgorithm<T extends PitchResult>`): `type`,
  `windowSize(sampleRate)`, `analyze(frame, step)`, `toJson()`. Built from
  JSON by `pitchAlgorithmFromJson` (a worker cannot receive closures). An
  algorithm may read the result of an earlier one of the same step (the
  reeds take the frequency found by YIN).

  | Type | Result | Use |
  |---|---|---|
  | `yin` | `PitchEstimate` | One note to the cent (YIN, its difference function by FFT) |
  | `autocorrelation` | `PitchEstimate` | One note, normalized autocorrelation |
  | `hps` | `PitchEstimate` | One note, harmonic product spectrum |
  | `harmonic_peeling` | `PitchEstimates` | Several notes, spectral peeling (matching pursuit) |
  | `poly_tuner` | `PitchTargets` | Cents of each target (the strings of an instrument) |
  | `hearing` | `PitchShares` | Share of the sound in the harmonics of each note: is a given note played, over other notes |
  | `reeds` | `PitchReeds` | The reeds of a held note (musette, violin registers): cents of each, beats per second of each pair, resolved on the harmonics where they are further apart |

- **Results** (`PitchResult`): JSON round trip, so steps cross a worker
  boundary.
- **Runner** (`PitchRunner`): sample rate, hop, named analyses (id +
  algorithm); `add(chunk)` returns the steps due; each `PitchStep` holds the
  results by id, the windows and, when timed, the microseconds each
  analysis took. Its configuration is JSON too.
- **Quality for display**: a steadied `PitchReading` (spread in cents,
  readings, seconds held, `stable()`), clarity documented per algorithm and
  a common `harmonicity`, per reed uncertainty and support, per string
  level (`sounds()`), the margin of a note over its neighbors, the level in
  dB, peak and clipping of each step, when each result was heard.
- **Smoothers**: median + exponential average over a time window (one per
  string), median tracker of the reeds of a held note.
- **Tunings** (`PitchTuning`): guitar (standard, drop D, DADGAD, open G),
  bass 4 and 5, ukulele, violin, viola, cello, mandolin, banjo; MIDI
  pitches, frequencies at any A4.
- **Test signals** (`package:tekartik_pitch/pitch_signal.dart`): sine,
  harmonic tone, plucked string, detuned reeds, mixes, noise, pitch drift.
  Tests build their sounds in memory, no binary assets.

## Steps

1. `tekartik_pitch` + `tekartik_audio_input`, with the tests of the
   experiments moved over (done, committed).
2. `tekartik_audio_input_flutter` (level widgets),
   `tekartik_audio_input_record` (microphone), `tekartik_pitch_flutter`,
   the level meter in `tekartik_audio_input`; the existing apps switch to
   them (done; the accordion app switched, not committed).
3. `tekartik_pitch_web_worker` (done): `PitchProcessor` / `PitchSession` in
   `tekartik_pitch` (the local one runs a `PitchRunner` here),
   `PitchWorkerProcessor` (web worker, isolate on io, main thread
   fallback), `PitchListening(processor:)`.
4. `pitch_lab` (done, demo `pitch_lab_demo` on tkhostelio dev: test sounds,
   microphone, WAV files, the five views, the worker switch); the
   experiments' copies are removed (to do).

Later: capture in an AudioWorklet of our own that posts straight to the
analysis worker (the `record` package goes through the main thread).

## Later: audio effects

This repository is also the home for audio effects (fade, normalize,
compress, limit, reverb...), in their own pure Dart package
(`tekartik_audio_effects`, `packages/effects`) on the same conventions:
mono (or per channel) `Float32List` buffers at a sample rate, and stateful
processors fed chunk by chunk, so the same effect runs on a whole file
(offline, with `tekartik_wav`) and on a live stream (an `AudioInput`, a
player). Shared pieces: the envelope of `AudioLevelMeter` for a compressor
or a limiter; the mixing algorithms of `tekartik_wav` (clamped, average,
soft clipped, normalized). Effects that need the whole sound (normalize to
a peak, trim silence) take a buffer; the others take chunks.

## Open questions

- Publish on pub.dev, or git dependencies only (like `tekartik_wav`).
- A bench of accuracy and time per algorithm over the test signals (a
  `bin/` tool) once the algorithms are in.
