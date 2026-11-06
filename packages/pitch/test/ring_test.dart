import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:test/test.dart';

Float32List _range(int from, int to) =>
    Float32List.fromList([for (var i = from; i < to; i++) i.toDouble()]);

void main() {
  group('ring', () {
    test('wraps around', () {
      var ring = PitchSampleRing(5);
      expect(ring.latest(3), [0, 0, 0]);
      ring.add(_range(1, 4));
      expect(ring.received, 3);
      expect(ring.latest(5), [0, 0, 1, 2, 3]);
      ring.add(_range(4, 8));
      expect(ring.received, 7);
      expect(ring.latest(5), [3, 4, 5, 6, 7]);
      expect(ring.latest(2), [6, 7]);
      expect(ring.latest(9), [3, 4, 5, 6, 7]);
    });

    test('more than its capacity at once', () {
      var ring = PitchSampleRing(4)..add(_range(1, 3));
      ring.add(_range(3, 13));
      expect(ring.received, 12);
      expect(ring.latest(4), [9, 10, 11, 12]);
      ring.clear();
      expect(ring.received, 0);
      expect(ring.latest(2), [0, 0]);
    });
  });
}
