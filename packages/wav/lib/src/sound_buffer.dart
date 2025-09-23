import 'dart:typed_data';

/// A buffer for holding and manipulating audio sample data.
class SoundBuffer {
  /// The sample rate of the audio data.
  late num sampleRate;

  /// The audio data as a list of 32-bit floats.
  late Float32List data;

  /// Creates a [SoundBuffer] with the given [sampleRate] and [length].
  SoundBuffer(this.sampleRate, int length) {
    data = Float32List(length);
  }

  /// Creates a view of another [SoundBuffer] starting at [index] for [count] elements.
  SoundBuffer.view(SoundBuffer sb, int index, int count) {
    sampleRate = sb.sampleRate;
    var float32size = sb.data.elementSizeInBytes;
    data = Float32List.view(sb.data.buffer, index * float32size, count);
  }

  /// Creates a [SoundBuffer] from existing [sampleRate] and [data].
  SoundBuffer.fromData(this.sampleRate, this.data);

  /// Returns the element at the given [index] in the list or throws
  /// an [RangeError] if [index] is out of bounds.
  double operator [](int index) {
    return data[index];
  }

  /// Sets the entry at the given [index] in the list to [value].
  /// Throws an [RangeError] if [index] is out of bounds.
  void operator []=(int index, double value) {
    data[index] = value;
  }

  /// The number of elements in the buffer.
  int get length {
    return data.length;
  }

  /// Shifts the buffer data by [length] elements.
  void shiftBy(int length) {
    data.setRange(0, this.length - length, data, length);
  }

  /// Computes the average of [count] elements starting at [index].
  double average(int index, int count) {
    var total = 0.0;
    for (var i = index; i < index + count; i++) {
      total += this[i];
    }
    return total / count;
  }

  @override
  String toString() {
    var sb = StringBuffer();
    sb.write('r ');
    sb.write(sampleRate);
    sb.write(' size ');
    sb.write(data.length);
    return sb.toString();
  }
}
