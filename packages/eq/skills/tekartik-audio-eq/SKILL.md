---
name: tekartik-audio-eq
description: >-
  Use when equalizing sound in dart with tekartik_audio_eq: parametric EQ
  bands (gain, frequency, Q; peaking, shelves, passes, notch), presets,
  biquad coefficients, the response curve of an EQ editor, the automatic
  preamp, processing PCM blocks without clicks (EqProcessor), a PipeWire
  filter-chain sink of a preset, or Web Audio BiquadFilterNode /
  IIRFilterNode parameters.
---

# Parametric equalizer (tekartik_audio_eq)

Pure dart (VM and web, no Flutter). One library:
`package:tekartik_audio_eq/audio_eq.dart`.

## Guidelines

* Depend on it from git:

  ```yaml
  dependencies:
    tekartik_audio_eq:
      git:
        url: https://github.com/tekartikprj/audio
        path: packages/eq
  ```

* Model: `EqBand` (type, frequency Hz, gain dB, q, enabled) and `EqPreset`
  (name, preamp dB, bands), immutable, `copyWith`, `toJson`/`fromJson`.
  Named constructors: `EqBand.peaking(f, gain, q:)`, `.lowShelf`,
  `.highShelf`, `.lowPass`, `.highPass`, `.notch`, `.bandPass`, `.allPass`.
  Gain is used by peaking and shelves only (`EqFilterType.hasGain`).
* Shelves: the frequency is the midpoint of the slope (half the gain in
  dB), the Q its steepness (`eqButterworthQ`, 0.7071, is the "S = 1" slope
  of Web Audio and of a 12 dB shelf).
* Curve: `EqResponse.compute(preset, sampleRate:, points:)` gives
  `frequencies` and `gains` (dB) on a log grid; `EqChain.fromPreset(preset,
  rate).gainDbAt(f)` for one frequency. `eqAutoPreamp(preset)` is the
  preamp that keeps the curve at or below 0 dB.
* Processing: `EqProcessor(channels:, sampleRate:, preset:)`, then
  `process(inputs, outputs)` (one `Float32List` per channel, may be the
  same lists) or `processInterleaved`. Set `preset` or `bypass` at any
  time: the old and new chains crossfade over `crossfadeFrames` (256); a
  change during a crossfade is applied when it ends. `reset()` after a
  seek. Invalid bands throw `ArgumentError` (frequency or Q not positive);
  frequencies above Nyquist are clamped.
* Numbers in a conf or a control: `eqFormatNumber(value)` (`105`, `0.7`).
* PipeWire: `formatEqPipeWireFilterChainConf(preset, nodeName:,
  targetObject:, slots:, crossfade:)` is a conf for `pipewire -c <file>` (a
  sink named `nodeName`, the chain lives as long as that process);
  `formatEqPipeWireParams(preset, slots:, path:)` is the `Props` value of
  `pw-cli set-param <sink node id> Props ...` for a live change (same node
  types only, `eqPipeWireSameChain`). A band heard that changes may click:
  with `crossfade: true`, send the change to the equalizer not heard
  (`path`), wait for its filters to settle (about 40 ms), then
  `formatEqPipeWireMixParams(EqPipeWireMix.path(path))` (gains move in
  about 25 ms, per sample); `EqPipeWireMix.bypass` for A/B. PipeWire
  1.6.2's `ramp` builtin is unusable (always 0).
* Web Audio: `eqWebAudioFilters(preset, contextSampleRate)`; a filter with
  `isBiquadNode` false is an `IIRFilterNode` (`feedforward`, `feedback`).
* Built in presets: `EqPresets.all` (flat first).
* WAV files: `dart run tekartik_audio_eq:eq_wav in.wav out.wav --preset
  preset.json` (a `toJson` preset) or `--builtin bass_boost`.
