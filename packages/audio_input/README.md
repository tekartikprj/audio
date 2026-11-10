# tekartik_audio_input

One interface for the sources of mono audio samples: an `AudioInput` gives
`Float32List` chunks (-1 to 1) from a microphone, from samples or a WAV file,
or pushed by hand in a test. An analysis (`tekartik_pitch`), a recorder or a
level meter then runs the same on all of them.

Pure Dart: Dart VM, Flutter (every platform) and the web. The microphone is
in `tekartik_audio_input_record` (the `record` plugin), the level widgets in
`tekartik_audio_input_flutter`.

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  tekartik_audio_input:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages/audio_input
```

Play one second of a 440 Hz sine as an input, as fast as possible, and
measure its level:

```dart
import 'dart:math';
import 'dart:typed_data';

import 'package:tekartik_audio_input/audio_input.dart';

Future<void> main() async {
  const sampleRate = 8000;
  var samples = Float32List.fromList([
    for (var i = 0; i < sampleRate; i++)
      0.5 * sin(2 * pi * 440 * i / sampleRate),
  ]);
  // speed 1 is real time (the default), 0 as fast as possible.
  var input = AudioInputSamples(samples, sampleRate: sampleRate, speed: 0);
  var meter = AudioLevelMeter(sampleRate: input.sampleRate);
  await for (var chunk in await input.start()) {
    print('${chunk.length} samples, ${meter.add(chunk)}');
  }
  // The stream ended with the samples (loop: false).
}
```

See [example/main.dart](example/main.dart) for a WAV file and a pushed
input.

## What to use

| Need | Use |
|---|---|
| Write code for any source | `AudioInput`: `start()` gives the chunk stream, `stop()` ends it, `sampleRate`, `latency` |
| Samples or a WAV file as an input | `AudioInputSamples(samples, sampleRate:, speed:, chunkSize:, loop:)`, `AudioInputSamples.wav(bytes)` (16 bit PCM, mixed to mono) |
| Samples pushed by hand (tests) | `AudioInputPush`, `push(samples)` once started |
| A level meter next to the analysis | `AudioInputMetered(input)`: give it to the consumer, show `levels` or `level` |
| A level from chunks, no input | `AudioLevelMeter(sampleRate:)`, `add(chunk)` gives an `AudioLevel` |
| 16 bit PCM bytes to samples | `AudioInputPcm16Decoder().convert(bytes)` (an odd byte is kept for the next chunk) |
| States and errors to show | `AudioInputState`, `AudioInputDenied` (permission), `AudioInputUnavailable` (no device, failure) |
| The user picks a microphone | `AudioInputDevice(id, label)` |

## Good to know

- `speed: 0` (as fast as possible) follows the listener: nothing is sent
  while the subscription is paused (an `await for` with an async body,
  `asyncMap`), nothing after it cancelled. In real time (`speed` above 0)
  the chunks come at the pace of the clock, as from a microphone.
- `loop: true` never ends the stream: call `stop()`.
- `AudioInputSamples.wav` throws a `FormatException` for anything but an
  uncompressed 16 bit PCM WAV (a sample rate of 0 included); the channels
  are mixed to mono.
- `AudioInputMetered.level` goes back to silence on `stop()`, not when the
  input ends by itself; no level comes while nobody listens to the stream of
  `start()`.
- Implementing an input: a listener that cancelled must not be waited for
  (closing the controller then never completes); see `AudioInputPush`.
