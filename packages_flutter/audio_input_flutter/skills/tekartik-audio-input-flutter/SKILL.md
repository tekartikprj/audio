---
name: tekartik-audio-input-flutter
description: >-
  Use when showing the level of an audio input in Flutter with
  tekartik_audio_input_flutter (a level bar with peak hold and clipping, a
  microphone icon pulsing with the sound) or metering any AudioInput
  independently of what consumes it (AudioInputMetered, AudioLevelMeter,
  AudioLevel from tekartik_audio_input).
---

# Audio level widgets (tekartik_audio_input_flutter)

## Guidelines

* Depend on it from git (no plugin: the microphone is in
  `tekartik_audio_input_record`):

  ```yaml
  dependencies:
    tekartik_audio_input_flutter:
      git:
        url: https://github.com/tekartikprj/audio
        path: packages_flutter/audio_input_flutter
  ```

* Meter independently of the consumer: wrap the input,
  `var input = AudioInputMetered(microphone)`, give `input` to the
  analysis or recording, and show `input.levels` / `input.level`. Without
  a consumer listening to `start()`'s stream no level comes.
* `AudioLevel`: `rms`, `peak` of the last chunk, `display` (rises at once,
  falls 24 dB/s), `heldPeak` (1.5 s), `clipped` (kept 1 s), the same in
  decibels, `quiet()`. `AudioLevelMeter(sampleRate:)` makes them from
  chunks when there is no `AudioInput` (a player, a file).
* Widgets: `AudioLevelBar(level:)` (-60 to 0 dB, peak tick, green / muted
  / red), `AudioLevelMic(level:)` (icon with a halo, for an app bar),
  `AudioInputLevelBuilder(input:, builder:)` and
  `AudioInputLevelBar(input:)` to follow an `AudioInputMetered`. Colors
  come from the theme (`AudioLevelColors.of`), or pass `colors:`.
* `AudioLevelBar` takes the whole width: in a `Row`, wrap it in `Expanded`
  (an unbounded width is a layout error). Any width works, down to 0.
* `example/main.dart`: a whole app metering a generated sine
  (`AudioInputSamples(..., loop: true)`), no microphone. In a widget test,
  `AudioInputSamples` in real time paces itself with a real stopwatch:
  alternate `tester.runAsync(() => Future.delayed(...))` and
  `tester.pump(...)`, or use `AudioInputPush`.
