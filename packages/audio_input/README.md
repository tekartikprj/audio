# tekartik_audio_input

Audio input abstraction in pure Dart: an `AudioInput` gives mono
`Float32List` chunks (-1 to 1) from a microphone (Flutter package to come),
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

`AudioInputState` (off, starting, on, denied, failed), `AudioInputDenied`
and `AudioInputUnavailable` are the states and errors shared by the
implementations.
