---
name: tekartik-audio-input-record
description: >-
  Use when reading the microphone as samples in a Flutter app with
  tekartik_audio_input_record: AudioInputMicrophone (record package, mono
  Float32 chunks, no automatic gain), its permission and failure errors,
  choosing an input device, and the platform permissions to declare.
---

# Microphone input (tekartik_audio_input_record)

## Guidelines

* Depend on it from git:

  ```yaml
  dependencies:
    tekartik_audio_input_record:
      git:
        url: https://github.com/tekartikprj/audio
        path: packages_flutter/audio_input_record
  ```

* `AudioInputMicrophone(sampleRate: 44100, device: null, latency: null)`
  implements `AudioInput` (`package:tekartik_audio_input`, re-exported):
  `start()` gives mono `Float32List` chunks in [-1, 1], `stop()` ends them,
  `dispose()` frees the recorder.
* Start it from a user gesture (the web asks for the microphone then).
  `start()` throws `AudioInputDenied` when not allowed and
  `AudioInputUnavailable` when there is no device or the recorder fails;
  map them to `AudioInputState.denied` / `failed` for the user.
* Automatic gain, echo cancellation and noise suppression are off: they
  flatten held notes and break pitch analysis.
* `listDevices()` lists `AudioInputDevice(id, label)` (labels may be empty
  on the web before the permission); pass one as `device:`.
* Declare the permission in the app: `RECORD_AUDIO` (Android),
  `NSMicrophoneUsageDescription` (iOS, macOS) and the
  `com.apple.security.device.audio-input` entitlement (macOS).
* Tests: use `AudioInputPush` or `AudioInputSamples` from
  `tekartik_audio_input` instead of the microphone.
