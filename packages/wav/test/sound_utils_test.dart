library;

import 'package:tekartik_wav/sound_utils.dart';
import 'package:test/test.dart';

void main() {
  group('sound buffer', () {
    test('view', () {
      var sb = SoundBuffer(1024, 100);
      sb.data.fillRange(0, 10, 1.0);

      sb = SoundBuffer.view(sb, 8, 4);
      expect(sb.sampleRate, equals(1024));
      expect(sb.length, equals(4));
      expect(sb[0], equals(1.0));
      expect(sb[1], equals(1.0));
      expect(sb[2], equals(0.0));
      expect(sb[3], equals(0.0));
    });
  });
}
