# tekartik_audio_eq

A parametric equalizer in pure Dart (VM, web, Flutter; no plugin): bands
set by gain, frequency and Q, their biquad coefficients (RBJ Audio EQ
Cookbook), the response curve, a reference processor for PCM blocks, built
in presets, and the PipeWire filter-chain and Web Audio forms of a preset.

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  tekartik_audio_eq:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages/eq
```

```dart
import 'dart:typed_data';

import 'package:tekartik_audio_eq/audio_eq.dart';

void main() {
  var preset = EqPreset(
    name: 'Warm',
    bands: const [
      EqBand.lowShelf(105, 4),
      EqBand.peaking(3000, -2, q: 1.4),
    ],
  );
  // Leave room for the boost: the curve stays at or below 0 dB.
  preset = preset.copyWith(preamp: eqAutoPreamp(preset));

  // The curve, for an editor.
  var response = EqResponse.compute(preset, points: 256);
  print('${response.maxGain} dB at most');

  // Blocks of PCM, one Float32List per channel, in place.
  var processor = EqProcessor(channels: 2, sampleRate: 48000, preset: preset);
  var left = Float32List(512);
  var right = Float32List(512);
  processor.process([left, right], [left, right]);

  // A change does not click: the chains crossfade.
  processor.preset = EqPresets.night;
}
```

Hear it (command line, no Flutter), in `packages/eq`:

- `dart run example/eq_ab_play.dart` plays a techno loop computed in Dart,
  5 s through a bass and treble boost (+12 dB and +10 dB), then 5 s
  without (a bypass, crossfaded), through `tekartik_audio_play` (`pw-play`,
  `paplay` or `aplay` on Linux, `afplay` on macOS, PowerShell on Windows).
- `dart run tekartik_common_build:web_run example/eq_ab_play.dart` (add
  `--wasm` for dart2wasm): the same file, computed and played in a headless
  Chrome (Web Audio, sound on), exits at the end.
- `dart run example/eq_ab_wav.dart out.wav` writes the sound.

## Features

- **Bands** (`EqBand`): peaking, low and high shelf, low and high pass,
  notch, band pass, all pass; frequency (Hz), gain (dB), Q, on/off. A
  preset (`EqPreset`) is a preamp and bands. Both are immutable, with a JSON
  form.
- **Coefficients** (`EqBiquad.fromBand`): the RBJ cookbook formulas, which
  are also those of PipeWire's builtin biquads (measured: within 0.003 dB of
  PipeWire 1.6.2).
- **Response** (`EqResponse`, `eqAutoPreamp`): gains on a log grid.
- **Processor** (`EqProcessor`): transposed direct form II in `double`, per
  channel or interleaved blocks, any block size (the output does not depend
  on it), crossfade on a change or a bypass, the oracle for a native engine.
- **PipeWire** (`formatEqPipeWireFilterChainArgs`,
  `formatEqPipeWireFilterChainConf`, `formatEqPipeWireParams`,
  `formatEqPipeWireMixParams`): a sink running the preset in a filter
  chain, its live controls; `slots` pads it with bands that change nothing
  (adding a peaking band stays a live change); `crossfade` gives it two
  equalizers and the dry sound mixed by smoothed gains (`EqPipeWireMix`):
  new controls go to the equalizer not heard, then a crossfade, so a live
  change or a bypass does not click (measured: no step above a smooth
  sine's, against 2.6 to 4 times for the same 18 dB sent to the band
  heard).
- **Web Audio** (`eqWebAudioFilters`): `BiquadFilterNode` parameters, or
  `IIRFilterNode` coefficients for a shelf Web Audio cannot play.
- **Presets** (`EqPresets`): flat, bass boost, treble cut, voice, loudness,
  night.
- **A sound to hear it on** (`eqDemoTechno`): techno at 128 BPM computed
  in Dart (kick and bass below 120 Hz, hats and clap above 4 kHz), mono,
  peaking at 0.35, the same samples on every call; the A/B examples play
  it.
- **CLI**: `dart run tekartik_audio_eq:eq_wav in.wav out.wav --preset
  preset.json` (the `EqPreset.toJson` form; or `--builtin bass_boost`,
  `--auto-preamp`).

## Pitfalls

- A live change of a PipeWire filter chain band that is heard (`pw-cli
  set-param`) may click: PipeWire applies controls once per block without
  smoothing, and the step grows with the change (a ramp of small steps is
  worse: more steps). Use a `crossfade` chain.
- PipeWire 1.6.2's `ramp` builtin outputs silence: its controls declare no
  range and the filter graph clamps every control to its range (0). The
  crossfade gains are a `sine` of frequency 0 (its `Offset`) through a
  40 Hz low pass instead.
- Web Audio's `lowpass` and `highpass` take their Q in dB, its shelves have
  no Q: `EqWebAudioFilter` converts.
