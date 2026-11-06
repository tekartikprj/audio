# tekartik_pitch_flutter

Flutter parts of pitch analysis (no plugin):

- `PitchListening`: runs `tekartik_pitch` analyses on an `AudioInput`
  (`AudioInputMicrophone` from `tekartik_audio_input_record`, a file, a
  test input): `state`, `level` (at each chunk, measured on its own) and
  `step` as `ValueNotifier`s, `onStep`, `a4`, `ago(step, id)`;
- `PitchListeningControl`: start / stop, why it failed, the level of the
  sound (bar and pulsing microphone), too loud;
- `PitchGauge` (a needle in cents), `PitchReedsView` (the reeds of a note
  and their beats), `PitchStringsView` (the strings of an instrument);
- `PitchColors`: the colors, from the theme by default.

It re-exports `tekartik_pitch` and `tekartik_audio_input_flutter`.

```dart
var listening = PitchListening(
  AudioInputMicrophone(),
  analyses: const [
    PitchAnalysis('yin', YinPitchAlgorithm()),
    PitchAnalysis('reeds', ReedsPitchAlgorithm(source: 'yin')),
  ],
);
PitchListeningControl(listening: listening, intro: 'Play a note');
```

## Setup

```yaml
dependencies:
  tekartik_pitch_flutter:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages_flutter/pitch_flutter
```
