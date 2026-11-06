---
name: tekartik-audio-input
description: >-
  Use when reading audio input as samples in dart with tekartik_audio_input:
  the AudioInput interface (start → Stream<Float32List>, stop, sampleRate,
  latency), playing a WAV file or computed samples as an input in real time
  or faster (AudioInputSamples), feeding samples by hand in tests
  (AudioInputPush), and the shared states and errors (AudioInputState,
  AudioInputDenied, AudioInputUnavailable).
---

# Audio input (tekartik_audio_input)

`tekartik_audio_input` is pure dart: one interface for the sources of mono
samples, so an analysis (`tekartik_pitch`) runs the same on a microphone, a
file or a test.

## Guidelines

* Depend on it from git:

  ```yaml
  dependencies:
    tekartik_audio_input:
      git:
        url: https://github.com/tekartikprj/audio
        path: packages/audio_input
  ```

* `AudioInput.start()` returns a `Stream<Float32List>` of mono chunks of
  any size in [-1, 1] at `sampleRate`; `stop()` ends the stream. `latency`
  is how late the samples come (0 for files and tests).
* Errors of `start()`: `AudioInputDenied` (permission), `AudioInputUnavailable`
  (no device, failure). Show them with `AudioInputState` (off, starting, on,
  denied, failed).
* `AudioInputSamples(samples, sampleRate:, speed: 1, chunkSize: 1024, loop:
  false)` plays samples: `speed` 1 is real time (paced on a stopwatch),
  2 twice as fast, 0 as fast as possible. `AudioInputSamples.wav(bytes)`
  reads a 16 bit PCM WAV (through `tekartik_wav`), channels mixed to mono,
  and throws a `FormatException` otherwise.
* `AudioInputPush` is fed by hand (`push(samples)` once started): tests and
  samples coming from elsewhere.
* Level of the sound, independent of the consumer: wrap any input,
  `var metered = AudioInputMetered(input)`, give `metered` to the
  consumer, show `metered.levels` / `metered.level` (`AudioLevel`: `rms`,
  `peak`, `display` falling 24 dB/s, `heldPeak` 1.5 s, `clipped` kept 1 s,
  decibels, `quiet()`); no level comes while nobody listens to the stream
  of `start()`. `AudioLevelMeter(sampleRate:)` measures chunks without an
  input. Widgets: `tekartik_audio_input_flutter`.
* `AudioInputDevice(id, label)` names an input the user may choose;
  `AudioInputPcm16Decoder().convert(bytes)` turns 16 bit PCM bytes into
  samples, carrying an odd byte to the next chunk.
* Implementing an input: a listener that cancelled must not be waited for
  (closing the controller then never completes); see `AudioInputPush`.
* The microphone is `AudioInputMicrophone` in `tekartik_audio_input_record`
  (the `record` plugin); the level widgets are in
  `tekartik_audio_input_flutter` (no plugin).
