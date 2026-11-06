import 'dart:math' as math;
import 'dart:typed_data';

/// The last [capacity] samples received.
class PitchSampleRing {
  /// How many samples are kept.
  final int capacity;

  final Float32List _samples;

  /// The samples received since the start (or the last [clear]).
  var received = 0;

  /// A ring keeping the last [capacity] samples.
  PitchSampleRing(this.capacity) : _samples = Float32List(capacity);

  /// Keeps [samples] (only their last [capacity] when more).
  void add(Float32List samples) {
    var count = samples.length;
    var from = 0;
    if (count > capacity) {
      from = count - capacity;
      received += from;
      count = capacity;
    }
    var start = received % capacity;
    var first = math.min(count, capacity - start);
    _samples.setRange(start, start + first, samples, from);
    if (first < count) {
      _samples.setRange(0, count - first, samples, from + first);
    }
    received += count;
  }

  /// A copy of the last [count] samples ([count] at most [capacity]), zeros
  /// before the first sample received.
  Float32List latest(int count) {
    count = math.min(count, capacity);
    var out = Float32List(count);
    var available = math.min(count, received);
    var start = (received - available) % capacity;
    var offset = count - available;
    var first = math.min(available, capacity - start);
    out.setRange(offset, offset + first, _samples, start);
    if (first < available) {
      out.setRange(offset + first, count, _samples);
    }
    return out;
  }

  /// Forgets the samples received.
  void clear() {
    received = 0;
    _samples.fillRange(0, capacity, 0);
  }
}
