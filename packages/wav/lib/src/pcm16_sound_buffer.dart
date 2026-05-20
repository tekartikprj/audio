import 'dart:typed_data';

import 'sound_buffer.dart';

/// A buffer for holding PCM 16-bit audio sample data.
class Pcm16SoundBuffer {
  /// The sample rate of the audio data.
  late num sampleRate;

  /// The audio data as a list of signed 16-bit integers in [-32768, 32767].
  late Int16List data;

  /// Creates a [Pcm16SoundBuffer] with the given [sampleRate] and [length].
  Pcm16SoundBuffer(this.sampleRate, int length) {
    data = Int16List(length);
  }

  /// Creates a [Pcm16SoundBuffer] from existing [sampleRate] and [data].
  Pcm16SoundBuffer.fromData(this.sampleRate, this.data);

  /// Creates a view of another [Pcm16SoundBuffer] starting at [index] for [count] elements.
  Pcm16SoundBuffer.view(Pcm16SoundBuffer sb, int index, int count) {
    sampleRate = sb.sampleRate;
    var int16size = sb.data.elementSizeInBytes;
    data = Int16List.view(sb.data.buffer, index * int16size, count);
  }

  /// Returns the element at the given [index] or throws [RangeError] if out of bounds.
  int operator [](int index) => data[index];

  /// Sets the entry at [index] to [value]. Throws [RangeError] if out of bounds.
  void operator []=(int index, int value) {
    data[index] = value;
  }

  /// The number of elements in the buffer.
  int get length => data.length;

  /// Converts this buffer to a [SoundBuffer], normalising values to [-1.0, 1.0].
  SoundBuffer toSoundBuffer() {
    var sb = SoundBuffer(sampleRate, length);
    for (var i = 0; i < length; i++) {
      sb[i] = data[i] / 32768.0;
    }
    return sb;
  }

  /// Creates a [Pcm16SoundBuffer] from a [SoundBuffer], clamping float values to [-1.0, 1.0].
  factory Pcm16SoundBuffer.fromSoundBuffer(SoundBuffer sb) {
    var pcm = Pcm16SoundBuffer(sb.sampleRate, sb.length);
    for (var i = 0; i < sb.length; i++) {
      var v = sb[i].clamp(-1.0, 1.0);
      pcm[i] = (v * 32767).round();
    }
    return pcm;
  }

  @override
  String toString() {
    return 'r $sampleRate size ${data.length}';
  }
}
