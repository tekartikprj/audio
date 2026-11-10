# tekartik_pitch_flutter

Flutter parts of pitch analysis (no plugin of its own):

- `PitchListening`: runs `tekartik_pitch` analyses on an `AudioInput`
  (`AudioInputMicrophone` from `tekartik_audio_input_record`, a file, a
  test input): `state`, `level` (at each chunk) and `step` as
  `ValueNotifier`s, `onStep`, `a4`, `ago(step, id)`;
- `PitchListeningControl`: start / stop, why it failed, the level of the
  sound (bar and pulsing microphone), too loud;
- `PitchGauge` (a needle in cents), `PitchReedsView` (the reeds of a note
  and their beats), `PitchStringsView` (the strings of an instrument);
- `PitchColors`: the colors, from the theme by default.

It re-exports `tekartik_pitch` and `tekartik_audio_input_flutter`. Widgets
are built on `package:material_ui`. Platforms: those of the input
(`tekartik_audio_input_record`: Android, iOS, macOS, Linux, Windows, web).

## Getting started

```yaml
dependencies:
  tekartik_pitch_flutter:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages_flutter/pitch_flutter
  # The microphone.
  tekartik_audio_input_record:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages_flutter/audio_input_record
  material_ui: '>=1.8.0'
```

```dart
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_audio_input_record/audio_input_record.dart';
import 'package:tekartik_pitch_flutter/pitch_flutter.dart';

/// A tuner: a start button, then the needle of the note heard.
class Tuner extends StatefulWidget {
  const Tuner({super.key});

  @override
  State<Tuner> createState() => _TunerState();
}

class _TunerState extends State<Tuner> {
  final _listening = PitchListening(
    AudioInputMicrophone(),
    analyses: const [PitchAnalysis('yin', YinPitchAlgorithm())],
  );

  @override
  void dispose() {
    // Stops the microphone, even while it is starting.
    _listening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PitchListeningControl(
      listening: _listening,
      intro: 'Play a note',
      child: ValueListenableBuilder<PitchStep?>(
        valueListenable: _listening.step,
        builder: (context, step, _) {
          // Null when nothing is heard.
          var estimate = step?.result<PitchEstimate>('yin');
          return PitchGauge(cents: estimate?.cents(a4: _listening.a4));
        },
      ),
    );
  }
}
```

A complete app: `apps/pitch_lab` in the repository.

## Pitfalls

- `start()` from a user gesture (the web asks for the microphone there).
- `stop()` or `dispose()` during `start()` win: the input is stopped once
  started, the state stays off.
- Steady what is shown (`PitchSmoother`, `PitchReedsTracker`): raw steps
  jump from one to the next.
- Widget tests: drive it with `AudioInputPush` and pump twice after a push
  (the step, then the rebuild).

More in the [package skill](skills/tekartik-pitch-flutter/SKILL.md).
