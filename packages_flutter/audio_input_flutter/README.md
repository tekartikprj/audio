# tekartik_audio_input_flutter

Flutter widgets showing the level of an audio input, without any plugin
(every Flutter platform):

- `AudioLevelBar`: the level from -60 to 0 dB, its held peak, green for a
  good level, muted when too quiet, red when clipping;
- `AudioLevelMic`: a microphone icon with a halo pulsing with the sound, a
  direct sign it comes in (fits an app bar);
- `AudioInputLevelBuilder` / `AudioInputLevelBar`: follow an
  `AudioInputMetered` (any input of
  [tekartik_audio_input](../../packages/audio_input/README.md) with its level
  measured, re-exported here).

The microphone itself is in
[tekartik_audio_input_record](../audio_input_record/README.md).

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  tekartik_audio_input_flutter:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages_flutter/audio_input_flutter
```

Wrap the input in an `AudioInputMetered`
(`AudioInputMetered(AudioInputMicrophone())` in an app), give it to the
consumer (an analysis, a recorder) and show its level:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:tekartik_audio_input_flutter/audio_input_flutter.dart';

/// The consumer of [input]: no level comes until something listens to the
/// chunks.
Future<StreamSubscription<Float32List>> startConsumer(
  AudioInputMetered input,
) async => (await input.start()).listen((chunk) {});

/// The level of [input] in the app bar and in a bar.
Widget levelScaffold(AudioInputMetered input) => Scaffold(
  appBar: AppBar(
    actions: [
      AudioInputLevelBuilder(
        input: input,
        builder: (context, level) => AudioLevelMic(level: level),
      ),
    ],
  ),
  body: AudioInputLevelBar(input: input),
);
```

[example/main.dart](example/main.dart) is a whole app on a generated sine
(no microphone).

## Good to know

* `AudioLevelBar` takes the whole width: in a `Row`, wrap it in `Expanded`
  (an unbounded width is a layout error).
* The level goes back to silence on `stop()` of the metered input; call
  `close()` once done with it.
* Colors come from the theme (`AudioLevelColors.of(context)`), or pass
  `colors:`.
* Without an input (a player, a file), `AudioLevelMeter(sampleRate:)` of
  tekartik_audio_input makes the `AudioLevel`s from the chunks.
