# tekartik_audio_input_record

The microphone of the device as a `tekartik_audio_input` `AudioInput`
(`AudioInputMicrophone`), through the `record` package: mono 16 bit PCM
turned to floats, no automatic gain, echo cancellation or noise
suppression, `AudioInputDenied` / `AudioInputUnavailable` errors, input
devices (`listDevices`, `device:`).

## Setup

```yaml
dependencies:
  tekartik_audio_input_record:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages_flutter/audio_input_record
```

Declare the microphone permission in the host app: `RECORD_AUDIO` on
Android, `NSMicrophoneUsageDescription` on iOS and macOS (and the
`com.apple.security.device.audio-input` entitlement on macOS).

```dart
var microphone = AudioInputMicrophone();
var chunks = await microphone.start(); // Stream<Float32List>
```
