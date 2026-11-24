import 'dart:math';
import 'dart:typed_data';

import 'eq_band.dart';
import 'eq_processor.dart';

/// Techno at 128 BPM, dry, to hear an equalizer on: the kick and the bass
/// line below 120 Hz, the hats and the clap above 4 kHz, a chord stab in
/// between. Four to the floor, an off beat bass line (A, A, F, G), hats on
/// the sixteenths, a clap on 2 and 4.
///
/// [seconds] long (10 by default), mono at [sampleRate], peaking at 0.35
/// (room for a boost before clipping). Computed in pure Dart, the same
/// samples on every call and platform (its noise has a fixed seed).
Float32List eqDemoTechno({double seconds = 10, int sampleRate = 48000}) =>
    _TechnoSynth(sampleRate, seconds).render();

class _TechnoSynth {
  static const _bpm = 128.0;
  static const _beat = 60 / _bpm;

  final int rate;
  final double seconds;
  final _random = Random(1);

  _TechnoSynth(this.rate, this.seconds);

  Float32List _track() => Float32List((seconds * rate).round());

  int _frame(double seconds) => (seconds * rate).round();

  /// Runs [track] through [preset]: the package's filters as a synth's.
  void _filter(Float32List track, EqPreset preset) => EqProcessor(
    channels: 1,
    sampleRate: rate.toDouble(),
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
      track[start + i] += tail * sample(i / rate);
    }
  }

  /// A kick: a sine falling from 155 Hz to 45 Hz.
  void _kick(Float32List track, double at) {
    var phase = 0.0;
    _add(track, at, _beat, (t) {
      phase += 2 * pi * (45 + 110 * exp(-t / 0.035)) / rate;
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
  void _noise(Float32List track, double at, double length, double decay) =>
      _add(
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
    var top = mix.fold(0.0, (top, value) => max(top, value.abs()));
    if (top > 0) {
      var factor = peak / top;
      for (var i = 0; i < mix.length; i++) {
        mix[i] *= factor;
      }
    }
    return mix;
  }

  Float32List render() {
    var kick = _track();
    var bass = _track();
    var hats = _track();
    var clap = _track();
    var stab = _track();
    const bassLine = [55.0, 55.0, 43.65, 49.0];
    var beats = (seconds / _beat).ceil();
    for (var b = 0; b < beats; b++) {
      var at = b * _beat;
      _kick(kick, at);
      _saw(bass, at + _beat / 2, 0.2, bassLine[(b ~/ 4) % 4], 0.12);
      for (var s = 0; s < 4; s++) {
        // Closed hats on the sixteenths, an open one on the off beat.
        var open = s == 2;
        _noise(
          hats,
          at + s * _beat / 4,
          open ? 0.12 : 0.03,
          open ? 0.05 : 0.01,
        );
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
}
