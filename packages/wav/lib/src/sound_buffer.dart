import 'dart:typed_data';

class SoundBuffer {
  late num sampleRate;
  late Float32List data;

  SoundBuffer(this.sampleRate, int length) {
    data = Float32List(length);
  }

  SoundBuffer.view(SoundBuffer sb, int index, int count) {
    sampleRate = sb.sampleRate;
    var float32size = sb.data.elementSizeInBytes;
    data = Float32List.view(sb.data.buffer, index * float32size, count);
  }

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

  int get length {
    return data.length;
  }

  void shiftBy(int length) {
    data.setRange(0, this.length - length, data, length);
  }

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
