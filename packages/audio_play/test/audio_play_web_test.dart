@TestOn('browser')
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:tekartik_audio_play/audio_play_web.dart';
import 'package:test/test.dart';

Float32List _tone(double seconds, int rate) => Float32List.fromList([
  for (var i = 0; i < seconds * rate; i++) 0.05 * sin(2 * pi * 440 * i / rate),
]);

void main() {
  test('the default player is Web Audio', () {
    expect(audioPlay, same(audioPlayWebDefault));
  });

  test('samples and wav bytes play to the end', () async {
    var play = AudioPlayWeb();
    var stopwatch = Stopwatch()..start();
    await play.playSamples([_tone(0.2, 48000)], sampleRate: 48000);
    expect(stopwatch.elapsed, greaterThan(const Duration(milliseconds: 150)));
    stopwatch.reset();
    await play.playWavBytes(
      audioSamplesToWavBytes([_tone(0.2, 44100)], sampleRate: 44100),
    );
    expect(stopwatch.elapsed, greaterThan(const Duration(milliseconds: 150)));
  });

  test('stop', () async {
    var play = AudioPlayWeb();
    var done = play.playSamples([_tone(5, 48000)], sampleRate: 48000);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    var stopwatch = Stopwatch()..start();
    await play.stop();
    await done;
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('not a sound', () async {
    await expectLater(
      AudioPlayWeb().playWavBytes(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<AudioPlayException>()),
    );
  });
}
