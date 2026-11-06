# tekartik_audio_input_flutter

Flutter widgets for audio inputs, without any plugin (the microphone
itself is in `tekartik_audio_input_record`):

- `AudioLevelBar`: the level from -60 to 0 dB, its held peak, green for a
  good level, muted when too quiet, red when clipping;
- `AudioLevelMic`: a microphone icon with a halo pulsing with the sound, a
  direct sign it comes in (fits an app bar);
- `AudioInputLevelBuilder` / `AudioInputLevelBar`: follow an
  `AudioInputMetered` (any input with its level measured, from
  `tekartik_audio_input`).

```dart
var input = AudioInputMetered(AudioInputMicrophone());
// The analysis or recording uses `input`, the screen shows its level:
AudioInputLevelBar(input: input);
AudioInputLevelBuilder(
  input: input,
  builder: (context, level) => AudioLevelMic(level: level),
);
```

## Setup

```yaml
dependencies:
  tekartik_audio_input_flutter:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages_flutter/audio_input_flutter
```
