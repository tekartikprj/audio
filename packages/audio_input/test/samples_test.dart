import 'dart:typed_data';

import 'package:tekartik_audio_input/audio_input.dart';
import 'package:tekartik_pitch/pitch.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file_fs.dart';
import 'package:test/test.dart';

Float32List _ramp(int length) =>
    Float32List.fromList([for (var i = 0; i < length; i++) i / length]);

void main() {
  group('samples', () {
    test('as fast as possible, the last chunk shorter', () async {
      var input = AudioInputSamples(
        _ramp(2500),
        sampleRate: 8000,
        speed: 0,
        chunkSize: 1000,
      );
      expect(input.duration, 2500 / 8000);
      expect(input.latency, 0);
      var chunks = await (await input.start()).toList();
      expect(chunks.map((chunk) => chunk.length), [1000, 1000, 500]);
      expect(chunks.last.last, closeTo(2499 / 2500, 1e-6));
      expect(input.started, isFalse);
    });

    test('looping, stopped', () async {
      var input = AudioInputSamples(
        _ramp(300),
        sampleRate: 8000,
        speed: 0,
        chunkSize: 200,
        loop: true,
      );
      var chunks = await (await input.start()).take(4).toList();
      expect(chunks.map((chunk) => chunk.length), [200, 200, 200, 200]);
      // 200..299 then 0..99.
      expect(chunks[1][99], closeTo(299 / 300, 1e-6));
      expect(chunks[1][100], 0);
      await input.stop();
      expect(input.started, isFalse);
      // Nothing: ends at once.
      var empty = AudioInputSamples(Float32List(0), sampleRate: 8000, speed: 0);
      expect(await (await empty.start()).toList(), isEmpty);
    });

    test('as fast as possible waits for a paused listener', () async {
      var input = AudioInputSamples(
        Float32List(1000),
        sampleRate: 8000,
        speed: 0,
        chunkSize: 1000,
        loop: true,
      );
      var received = 0;
      var subscription = (await input.start()).listen((_) => received++);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received, greaterThan(0));
      subscription.pause();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      received = 0;
      subscription.resume();
      // What was buffered while paused comes now, in microtasks.
      await Future<void>.delayed(Duration.zero);
      expect(received, lessThan(5));
      await subscription.cancel();
      await input.stop();
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('in real time, four times faster', () async {
      // 0.4 s of samples at 4 times: about 0.1 s.
      var input = AudioInputSamples(
        Float32List(3200),
        sampleRate: 8000,
        speed: 4,
        chunkSize: 400,
      );
      var stopwatch = Stopwatch()..start();
      var chunks = await (await input.start()).toList();
      expect(chunks, hasLength(8));
      expect(stopwatch.elapsedMilliseconds, inInclusiveRange(80, 1000));
    });

    test('a WAV file, stereo to mono', () async {
      var left = Float32List.fromList([0.5, 0.5, 0.5, 0.5]);
      var right = Float32List.fromList([0, -0.5, 0.5, 0]);
      var bytes = writeWavBytes(
        sampleRate: 22050,
        numChannels: 2,
        soundBuffers: [
          SoundBuffer.fromData(22050, left),
          SoundBuffer.fromData(22050, right),
        ],
      );
      var input = AudioInputSamples.wav(bytes, speed: 0, chunkSize: 4);
      expect(input.sampleRate, 22050);
      var chunk = (await (await input.start()).toList()).single;
      expect(chunk[0], closeTo(0.25, 1e-3));
      expect(chunk[1], closeTo(0, 1e-3));
      expect(chunk[2], closeTo(0.5, 1e-3));
      expect(
        () => AudioInputSamples.wav(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });

    test('a WAV file of 0 Hz is refused', () {
      // In real time it would never send nor end.
      var bytes = writeWavBytes(
        sampleRate: 0,
        numChannels: 1,
        soundBuffers: [SoundBuffer.fromData(0, Float32List(100))],
      );
      expect(() => AudioInputSamples.wav(bytes), throwsFormatException);
    });

    test('a musette in a WAV file, through the pitch runner', () async {
      var musette = PitchSignal.reeds(440, [-19.6, 0, 19.6]);
      var bytes = writeWavBytes(
        sampleRate: 44100,
        numChannels: 1,
        soundBuffers: [SoundBuffer.fromData(44100, musette)],
      );
      var input = AudioInputSamples.wav(bytes, speed: 0);
      var runner = PitchRunner(
        sampleRate: input.sampleRate,
        analyses: const [
          PitchAnalysis('yin', YinPitchAlgorithm()),
          PitchAnalysis('reeds', ReedsPitchAlgorithm(source: 'yin')),
        ],
      );
      var steps = await runner.bind(await input.start()).toList();
      var reeds = steps.last.result<PitchReeds>('reeds')!;
      expect(reeds.pitch, 69);
      expect(reeds.reeds.map((reed) => reed.cents.round()), [-20, 0, 20]);
      expect(reeds.beats[1], closeTo(5.0, 0.1));
    });
  });
}
