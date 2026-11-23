# tekartik_audio_play

Plays WAV bytes or float samples from Dart, on the VM and in a browser:

- **VM** (a command line script, a server, a desktop app without Flutter):
  through the player the OS ships, no native code, nothing to install:
  `pw-play`, `paplay` or `aplay` on Linux, `afplay` on macOS, PowerShell's
  `System.Media.SoundPlayer` on Windows. On PipeWire (and PulseAudio) a
  sound can go to a chosen sink with stream properties
  (`application.name`, `node.name`...), to be told from the others.
- **Browser**: Web Audio (an `AudioBufferSourceNode` per sound).

For live streaming with a low latency, see `tekartik_port_audio`
(`tekartikprj/milomedy`, PortAudio through FFI; a native library to
install).

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  tekartik_audio_play:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages/audio_play
```

```dart
import 'dart:math';
import 'dart:typed_data';

import 'package:tekartik_audio_play/audio_play.dart';

Future<void> main() async {
  const sampleRate = 48000;
  var tone = Float32List.fromList([
    for (var i = 0; i < sampleRate; i++)
      0.2 * sin(2 * pi * 440 * i / sampleRate),
  ]);
  // The player of this platform; completes at the end of the sound.
  await audioPlaySamples([tone], sampleRate: sampleRate);
}
```

`dart run example/audio_play_example.dart` plays that tone; the same file
in a headless Chrome: `dart run tekartik_common_build:web_run
example/audio_play_example.dart` (`--wasm` for dart2wasm).

## Libraries

- `audio_play.dart` (VM and web): `AudioPlay` (`playWavBytes`,
  `playSamples`, `stop`), `audioPlay` (the player of this platform),
  `audioPlaySamples`, `audioPlayWavBytes`, `audioSamplesToWavBytes`,
  `AudioPlayException`.
- `audio_play_io.dart` (VM): `AudioPlayIo` (`playWavFile` too), its
  `AudioPlayIoOptions` (`target`, `properties`), the players
  (`AudioPlayIoPlayer.pwPlay`, `paplay`, `aplay`, `afplay`,
  `windowsSoundPlayer`, or your own), `audioPlayIoFindPlayer`.

  ```dart
  // To a PipeWire sink, labelled (a test tone into a null sink).
  await AudioPlayIo(
    options: const AudioPlayIoOptions(
      target: 'my_null_sink',
      properties: {'application.name': 'my-test'},
    ),
  ).playWavFile('tone.wav');
  ```

- `audio_play_web.dart` (browser): `AudioPlayWeb` on an `AudioContext`.

## Pitfalls

- A browser starts an `AudioContext` suspended until the user interacts
  with the page: play the first sound from a click or a key press, or the
  play waits for one. Headless Chrome (tests, scripts):
  `--autoplay-policy=no-user-gesture-required` (and `--mute-audio` to
  keep the speakers quiet, the sounds still end). See `dart_test.yaml`.
- `aplay`, `afplay` and the Windows player only play to the default
  device: an `AudioPlayIo` with a `target` picks `pw-play` or `paplay`, and
  refuses a player without one rather than play to the speakers.
- Chrome on Linux plays through PulseAudio: `PULSE_SINK=<sink>` in its
  environment sends it to another sink (a null sink for a test).
- Checked on Linux (PipeWire 1.6.2: pw-play, paplay; Chrome); the macOS and
  Windows players are written, not run yet:
  `dart test test/audio_play_io_test_manual.dart` there.

## Tests

`dart test` (VM, a fake player) and `dart test -p chrome` (Web Audio,
muted). By hand, real players: `dart test
test/audio_play_io_test_manual.dart` (Linux: a null sink, nothing reaches
the speakers; macOS and Windows: a quiet tone).
