import 'eq_band.dart';

/// Built in presets, a starting point to edit. Their preamp leaves room for
/// their boosts (about the highest gain of the curve).
abstract final class EqPresets {
  /// No change.
  static final flat = EqPreset.flat;

  /// More low end: a low shelf of +6 dB at 105 Hz.
  static final bassBoost = EqPreset(
    name: 'Bass boost',
    preamp: -6,
    bands: const [EqBand.lowShelf(105, 6)],
  );

  /// Less highs: a high shelf of -6 dB at 6 kHz.
  static final trebleCut = EqPreset(
    name: 'Treble cut',
    bands: const [EqBand.highShelf(6000, -6)],
  );

  /// Speech forward: rumble off below 80 Hz, less boom at 250 Hz, presence
  /// at 3 kHz.
  static final voice = EqPreset(
    name: 'Voice',
    preamp: -4,
    bands: const [
      EqBand.highPass(80),
      EqBand.peaking(250, -3, q: 1),
      EqBand.peaking(3000, 4, q: 1),
    ],
  );

  /// The low and high ends raised, as a loudness contour does at a low
  /// volume.
  static final loudness = EqPreset(
    name: 'Loudness',
    preamp: -6,
    bands: const [EqBand.lowShelf(100, 6), EqBand.highShelf(10000, 4)],
  );

  /// Late listening: less bass and treble (the preamp stays at 0 dB: raising
  /// it back would clip the loud parts).
  static final night = EqPreset(
    name: 'Night',
    bands: const [EqBand.lowShelf(120, -8), EqBand.highShelf(8000, -4)],
  );

  /// Every built in preset, [flat] first.
  static final all = List<EqPreset>.unmodifiable([
    flat,
    bassBoost,
    trebleCut,
    voice,
    loudness,
    night,
  ]);
}
