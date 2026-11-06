# tekartik_audio_input

Audio input abstraction in pure Dart: an `AudioInput` gives mono
`Float32List` chunks (-1 to 1) from a microphone (`tekartik_audio_input_record`),
from samples or a WAV file (`AudioInputSamples`, played in real time,
faster or as fast as possible, looping or not) or by hand
(`AudioInputPush`, for tests).

## Setup

```yaml
dependencies:
  tekartik_audio_input:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages/audio_input
```

## Usage

```dart
import 'package:tekartik_audio_input/audio_input.dart';

var input = AudioInputSamples.wav(bytes); // real time
var chunks = await input.start();
chunks.listen((samples) {/* analyze */});
await input.stop();
```
## Level of the sound

Show that the sound comes in, independently of what uses it:

```dart
var input = AudioInputMetered(microphone); // any AudioInput
// The analysis or recording starts and listens to `input`;
// a meter shows `input.levels` (a stream) or `input.level`.
```

`AudioLevel` holds the RMS and peak of the last chunk, a displayed level
rising at once and falling 24 dB/s, the peak held 1.5 s, clipping kept
1 s, the same in decibels and `quiet()`. `AudioLevelMeter` makes them from
chunks without an input (a player, a file). The Flutter widgets are in
`tekartik_audio_input_flutter`.

Also: `AudioInputDevice` (an input the user may choose),
`AudioInputPcm16Decoder` (16 bit PCM bytes to samples, chunk by chunk).

`AudioInputState` (off, starting, on, denied, failed), `AudioInputDenied`
and `AudioInputUnavailable` are the states and errors shared by the
implementations.
