// The sample of the A/B examples, computed in pure Dart (no dart:io: it
// runs on the VM and in a browser alike): ten seconds of techno,
// the first five through [technoAbBoost], the last five without it.
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
const _bpm = 128.0;
const _beat = 60 / _bpm;
const _half = 5.0;

final _random = Random(1);

Float32List _track() => Float32List((2 * _half * _rate).round());

int _frame(double seconds) => (seconds * _rate).round();

/// Runs [track] through [preset]: the package's filters as a synth's.
void _filter(Float32List track, EqPreset preset) => EqProcessor(
  channels: 1,
  sampleRate: _rate.toDouble(),
  preset: preset,
).process([track], [track]);

/// Adds [length] seconds at [at] of [sample] (a function of the time from
/// the note start), faded out over its last 5 ms.
void _add(
  Float32List track,
  double at,
  double length,
  double Function(double t) sample,
) {
  var start = _frame(at);
  var frames = _frame(length);
  var fade = _frame(0.005);
  for (var i = 0; i < frames && start + i < track.length; i++) {
    var tail = frames - i < fade ? (frames - i) / fade : 1.0;
    track[start + i] += tail * sample(i / _rate);
  }
}

/// A kick: a sine falling from 155 Hz to 45 Hz.
void _kick(Float32List track, double at) {
  var phase = 0.0;
  _add(track, at, _beat, (t) {
    phase += 2 * pi * (45 + 110 * exp(-t / 0.035)) / _rate;
    return min(1.0, t / 0.001) * exp(-t / 0.18) * sin(phase);
  });
}

/// A sawtooth note of [frequency], its level falling with [decay].
void _saw(
  Float32List track,
  double at,
  double length,
  double frequency,
  double decay,
) {
  _add(track, at, length, (t) {
    var cycle = t * frequency;
    return min(1.0, t / 0.004) *
        exp(-t / decay) *
        (2 * (cycle - cycle.floorToDouble()) - 1);
  });
}

/// A burst of white noise, its level falling with [decay].
void _noise(Float32List track, double at, double length, double decay) => _add(
  track,
  at,
  length,
  (t) => exp(-t / decay) * (_random.nextDouble() * 2 - 1),
);

/// [tracks] mixed with their [levels], the result peaking at [peak].
Float32List _mix(List<Float32List> tracks, List<double> levels, double peak) {
  var mix = _track();
  for (var i = 0; i < mix.length; i++) {
    for (var t = 0; t < tracks.length; t++) {
      mix[i] += levels[t] * tracks[t][i];
    }
  }
  _scale(mix, peak);
  return mix;
}

double _peak(Float32List track) =>
    track.fold(0.0, (peak, value) => max(peak, value.abs()));

void _scale(Float32List track, double peak) {
  var factor = peak / _peak(track);
  for (var i = 0; i < track.length; i++) {
    track[i] *= factor;
  }
}

/// Ten seconds of techno at 128 BPM: four to the floor, an off beat bass
/// line (A, A, F, G), hats, a clap on 2 and 4, a minor chord stab.
Float32List _techno() {
  var kick = _track();
  var bass = _track();
  var hats = _track();
  var clap = _track();
  var stab = _track();
  const bassLine = [55.0, 55.0, 43.65, 49.0];
  var beats = (2 * _half / _beat).ceil();
  for (var b = 0; b < beats; b++) {
    var at = b * _beat;
    _kick(kick, at);
    _saw(bass, at + _beat / 2, 0.2, bassLine[(b ~/ 4) % 4], 0.12);
    for (var s = 0; s < 4; s++) {
      // Closed hats on the sixteenths, an open one on the off beat.
      var open = s == 2;
      _noise(hats, at + s * _beat / 4, open ? 0.12 : 0.03, open ? 0.05 : 0.01);
    }
    if (b % 2 == 1) {
      for (var flam = 0; flam < 3; flam++) {
        _noise(clap, at + flam * 0.008, 0.008, 0.004);
      }
      _noise(clap, at + 0.024, 0.25, 0.08);
    }
    if (b % 4 == 1 || b % 4 == 3) {
      for (var note in [220.0, 261.63, 329.63]) {
        _saw(stab, at + 3 * _beat / 4, 0.2, note, 0.08);
      }
    }
  }
  _filter(bass, EqPreset(bands: const [EqBand.lowPass(500, q: 1.5)]));
  _filter(hats, EqPreset(bands: const [EqBand.highPass(7000)]));
  _filter(clap, EqPreset(bands: const [EqBand.bandPass(1400, q: 0.9)]));
  _filter(stab, EqPreset(bands: const [EqBand.lowPass(2200, q: 0.9)]));
  return _mix(
    [kick, bass, hats, clap, stab],
    [0.55, 0.45, 0.22, 0.25, 0.14],
    0.35,
  );
}

/// The sample: [technoAbHalf] seconds through [technoAbBoost], then as
/// many without it (the bypass crossfades over 50 ms: the default 256
/// frames, 5 ms, would thump with 12 dB of bass going away), mono at
/// [technoAbSampleRate], peaking at 0.9 at most.
Float32List renderTechnoAb() {
  var sound = _techno();
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
  if (_peak(sound) > 0.9) {
    _scale(sound, 0.9);
  }
  return sound;
}
