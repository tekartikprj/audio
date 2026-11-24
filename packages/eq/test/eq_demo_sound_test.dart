import 'dart:math';
import 'dart:typed_data';

import 'package:tekartik_audio_eq/audio_eq.dart';
import 'package:test/test.dart';

double _peak(Float32List data) =>
    data.fold(0.0, (peak, value) => max(peak, value.abs()));

/// The RMS level (dB) of [data] through [preset].
double _levelThrough(Float32List data, EqPreset preset) {
  var copy = Float32List.fromList(data);
  EqProcessor(
    channels: 1,
    sampleRate: 48000,
    preset: preset,
  ).process([copy], [copy]);
  var sum = copy.fold(0.0, (sum, value) => sum + value * value);
  return eqLinearToDb(sqrt(sum / copy.length));
}

void main() {
  group('eqDemoTechno', () {
    test('length, peak, the same on every call', () {
      var sound = eqDemoTechno();
      expect(sound.length, 480000);
      expect(_peak(sound), closeTo(0.35, 1e-6));
      expect(eqDemoTechno(), sound);
      expect(eqDemoTechno(seconds: 2, sampleRate: 44100).length, 88200);
    });

    test('bass and treble to hear an equalizer on', () {
      var sound = eqDemoTechno(seconds: 4);
      var bass = _levelThrough(
        sound,
        EqPreset(bands: const [EqBand.lowPass(120)]),
      );
      var treble = _levelThrough(
        sound,
        EqPreset(bands: const [EqBand.highPass(4000)]),
      );
      // Both well above silence (the whole mix is about -20 dB RMS).
      expect(bass, greaterThan(-35));
      expect(treble, greaterThan(-45));
    });
  });
}
