---
name: tekartik-pitch-flutter
description: >-
  Use when building a tuner or a pitch display in Flutter with
  tekartik_pitch_flutter: PitchListening (running tekartik_pitch analyses
  on an audio input, state, level, steps as ValueNotifiers), the start and
  stop control with the level of the sound, the needle gauge, the reeds
  view, the strings view, and their colors from the theme.
---

# Pitch widgets (tekartik_pitch_flutter)

## Guidelines

* Depend on it from git; add `tekartik_audio_input_record` for the
  microphone (this package has no plugin):

  ```yaml
  dependencies:
    tekartik_pitch_flutter:
      git:
        url: https://github.com/tekartikprj/audio
        path: packages_flutter/pitch_flutter
  ```

* `PitchListening(input, analyses: [...], hop: 2048, a4: 440)`:
  `start()` from a user gesture, `stop()`, `dispose()` (a `stop()` or a
  `dispose()` while `start()` waits for the microphone permission wins:
  the input is stopped once started, the state stays off); `state`
  (`AudioInputState`), `level` (`AudioLevel` at each chunk: the input is
  wrapped in an `AudioInputMetered` unless it is one), `step` (the last
  `PitchStep`) are `ValueNotifier`s; `onStep` gets every step;
  `a4 = 442` updates the analyses at once; `ago(step, id)` is how long ago
  the sound of a result was heard (latency + half its window);
  `processor: PitchWorkerProcessor()` (tekartik_pitch_web_worker) runs the
  analyses in a web worker or an isolate (steps then arrive
  asynchronously).
* The widgets are built on `package:material_ui`: the app imports
  `package:material_ui/material_ui.dart`, not `package:flutter/material.dart`
  (the two Material libraries do not mix). A complete tuner:
  the package README; a full app: `apps/pitch_lab`.
* Widgets take their colors from the theme (`PitchColors.of`,
  `AudioLevelColors.of`) or `colors:`: `PitchListeningControl(listening:,
  intro:, child:, labels:)` (pass translated `PitchListeningLabels`),
  `PitchGauge(cents:)`, `PitchReedsView(reeds:, beatsLabel:)`,
  `PitchStringsView(strings: [PitchStringState(name, cents:, stable:)])`
  (dimmed when `cents` is null), plus the level widgets re-exported from
  `tekartik_audio_input_flutter` (`AudioLevelBar`, `AudioLevelMic`).
* Steady what is shown: `PitchSmoother` / `PitchReading.stable()` for a
  note, `PitchSmootherBank` with `PitchTarget.sounds()` for strings,
  `PitchReedsTracker` for reeds.
* Widget tests: drive it with `AudioInputPush` and pump twice after a push
  (the step, then the rebuild). Do not `await` a
  `StreamSubscription.cancel()` in a widget test: its completed root zone
  future stops the following awaits (`PitchListening.stop` does not await
  it for that reason).
