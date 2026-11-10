# tekartik_audio_input_record

The microphone of the device as a
[tekartik_audio_input](../../packages/audio_input/README.md) `AudioInput`
(`AudioInputMicrophone`), through the [record](https://pub.dev/packages/record)
plugin: mono 16 bit PCM turned to floats (-1 to 1), with no automatic gain,
echo cancellation or noise suppression (they flatten held notes).

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  tekartik_audio_input_record:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages_flutter/audio_input_record
```

Declare the microphone permission in the app (see Platforms), then, from a
user gesture:

```dart
import 'dart:async';
import 'dart:math';

import 'package:tekartik_audio_input_record/audio_input_record.dart';

/// Listens to the microphone for [duration]: the loudest level heard in
/// dB, null when the microphone is not allowed or missing.
Future<double?> loudestDecibels(Duration duration) async {
  var microphone = AudioInputMicrophone();
  var meter = AudioLevelMeter(sampleRate: microphone.sampleRate);
  var loudest = double.negativeInfinity;
  try {
    var chunks = await microphone.start();
    var subscription = chunks.listen((chunk) {
      loudest = max(loudest, meter.add(chunk).decibels);
    });
    await Future<void>.delayed(duration);
    await subscription.cancel();
    return loudest;
  } on AudioInputDenied {
    return null; // tell the user to allow the microphone
  } on AudioInputUnavailable {
    return null; // no microphone, or the recorder failed
  } finally {
    await microphone.dispose();
  }
}
```

## Platforms

| Platform | Setup |
|---|---|
| Android | `RECORD_AUDIO` in the app's `AndroidManifest.xml` |
| iOS, macOS | `NSMicrophoneUsageDescription` in `Info.plist`; macOS: the `com.apple.security.device.audio-input` entitlement |
| Web | Start from a user gesture (the browser asks for the microphone then); https or localhost |
| Linux | `parecord` and `pactl` (PulseAudio or PipeWire utilities) installed |
| Windows | Nothing |

## Good to know

* `start()` throws `AudioInputDenied` when not allowed and
  `AudioInputUnavailable` when there is no device or the recorder fails.
* `stop()` ends the stream of `start()`; a `stop()` (or `dispose()`) called
  while `start()` is still asking for the permission wins: `start()` then
  returns an ended stream and the microphone stays off.
* `listDevices()` gives the `AudioInputDevice`s (labels may be empty on the
  web before the permission), pass one as `device:`.
* `sampleRate` (44100 by default) is the rate asked; the web resamples to
  it, a native recorder may adjust it to the hardware (record's
  `setOnConfigChanged`, not followed here).
* Tests: use `AudioInputPush` or `AudioInputSamples` of tekartik_audio_input
  instead of the microphone; this package's tests fake record's platform
  (`test/src/fake_record_platform.dart`).
