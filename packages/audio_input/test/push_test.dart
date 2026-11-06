import 'dart:typed_data';

import 'package:tekartik_audio_input/audio_input.dart';
import 'package:test/test.dart';

void main() {
  group('push', () {
    test('pushed samples, before and after', () async {
      var input = AudioInputPush(sampleRate: 16000, latency: 0.1);
      expect(input.sampleRate, 16000);
      expect(input.latency, 0.1);
      input.push(Float32List(10));
      expect(input.started, isFalse);
      var stream = await input.start();
      expect(input.started, isTrue);
      var chunks = stream.toList();
      input
        ..push(Float32List(3))
        ..push(Float32List(5));
      await input.stop();
      expect(input.started, isFalse);
      expect((await chunks).map((chunk) => chunk.length), [3, 5]);
    });
  });
}
