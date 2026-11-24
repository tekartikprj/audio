// The sample of the A/B examples, computed in pure Dart (no dart:io: it
// runs on the VM and in a browser alike): ten seconds of techno
// (`eqDemoTechno`), the first five through [technoAbBoost], the last five
// without it.
import 'dart:math';
import 'dart:typed_data';

import 'package:tekartik_audio_eq/audio_eq.dart';

/// The sample rate of [renderTechnoAb] (Hz).
const technoAbSampleRate = _rate;

/// Each half, with then without the effect (seconds).
const technoAbHalf = _half;

/// The effect heard first, a "smile" curve made to be obvious: +12 dB of
/// bass below about 120 Hz (the kick, the bass line) and +10 dB of treble
/// above about 4 kHz (the hats, the clap). No preamp: when the boosted half
/// would clip, the whole 10 s is scaled down alike, so the A/B stays fair
/// (a live stream would take `eqAutoPreamp(technoAbBoost)` as its preamp
/// instead).
final technoAbBoost = EqPreset(
  name: 'Bass and treble boost',
  bands: const [EqBand.lowShelf(120, 12), EqBand.highShelf(4000, 10)],
);

/// What [technoAbBoost] does, as printed.
const technoAbBoostText =
    '+12 dB of bass below 120 Hz, +10 dB of treble above 4 kHz';

const _rate = 48000;
const _half = 5.0;

int _frame(double seconds) => (seconds * _rate).round();

double _peak(Float32List track) =>
    track.fold(0.0, (peak, value) => max(peak, value.abs()));

/// The sample: [technoAbHalf] seconds through [technoAbBoost], then as
/// many without it (the bypass crossfades over 50 ms: the default 256
/// frames, 5 ms, would thump with 12 dB of bass going away), mono at
/// [technoAbSampleRate], peaking at 0.9 at most.
Float32List renderTechnoAb() {
  var sound = eqDemoTechno(seconds: 2 * _half, sampleRate: _rate);
  var processor = EqProcessor(
    channels: 1,
    sampleRate: _rate.toDouble(),
    preset: technoAbBoost,
    crossfadeFrames: _frame(0.05),
  );
  const block = 480;
  for (var offset = 0; offset < sound.length; offset += block) {
    if (offset >= _frame(_half)) {
      processor.bypass = true;
    }
    var view = Float32List.sublistView(
      sound,
      offset,
      min(offset + block, sound.length),
    );
    processor.process([view], [view]);
  }
  // No clipping: both halves scaled alike, the A/B stays fair.
  var peak = _peak(sound);
  if (peak > 0.9) {
    var factor = 0.9 / peak;
    for (var i = 0; i < sound.length; i++) {
      sound[i] *= factor;
    }
  }
  return sound;
}
