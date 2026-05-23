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

  /// Validates that buffers is not empty, and all buffers have the same length and sample rate.
  static void _validateBuffers(Iterable<Pcm16SoundBuffer> buffers) {
    if (buffers.isEmpty) {
      throw ArgumentError('List of buffers cannot be empty');
    }
    var first = buffers.first;
    var length = first.length;
    var sampleRate = first.sampleRate;
    for (var buffer in buffers) {
      if (buffer.length != length) {
        throw ArgumentError('All buffers must have the same length');
      }
      if (buffer.sampleRate != sampleRate) {
        throw ArgumentError('All buffers must have the same sample rate');
      }
    }
  }

  /// Mixes a list of [Pcm16SoundBuffer]s by summing the samples and clamping to [-32768, 32767].
  ///
  /// This is simple and loud but can introduce hard clipping distortion if the sum exceeds limits.
  static Pcm16SoundBuffer mixClamped(Iterable<Pcm16SoundBuffer> buffers) {
    _validateBuffers(buffers);
    var list = buffers.toList();
    var first = list[0];
    var result = Pcm16SoundBuffer(first.sampleRate, first.length);
    for (var i = 0; i < result.length; i++) {
      var sum = 0;
      for (var b in list) {
        sum += b[i];
      }
      result[i] = sum.clamp(-32768, 32767);
    }
    return result;
  }

  /// Mixes a list of [Pcm16SoundBuffer]s by taking the average of the samples.
  ///
  /// This prevents any clipping distortion, but lowers the volume of each source buffer.
  static Pcm16SoundBuffer mixAverage(Iterable<Pcm16SoundBuffer> buffers) {
    _validateBuffers(buffers);
    var list = buffers.toList();
    var first = list[0];
    var result = Pcm16SoundBuffer(first.sampleRate, first.length);
    var count = list.length;
    for (var i = 0; i < result.length; i++) {
      var sum = 0;
      for (var b in list) {
        sum += b[i];
      }
      result[i] = (sum / count).round().clamp(-32768, 32767);
    }
    return result;
  }

  /// Mixes a list of [Pcm16SoundBuffer]s using a non-linear soft-clipping algorithm.
  ///
  /// The buffers are mixed sequentially. For each step, if both samples are positive,
  /// they are compressed dynamically. If both are negative, they are compressed towards the bottom limit.
  /// Otherwise, they are summed directly. This keeps the volume loud while preventing clipping.
  static Pcm16SoundBuffer mixSoftClipped(Iterable<Pcm16SoundBuffer> buffers) {
    _validateBuffers(buffers);
    var list = buffers.toList();
    var first = list[0];
    var result = Pcm16SoundBuffer(first.sampleRate, first.length);
    // Copy the first buffer
    for (var i = 0; i < first.length; i++) {
      result[i] = first[i];
    }
    // Sequentially mix the remaining buffers
    for (var b = 1; b < list.length; b++) {
      var next = list[b];
      for (var i = 0; i < result.length; i++) {
        var a = result[i];
        var bVal = next[i];
        int mixed;
        if (a < 0 && bVal < 0) {
          mixed = (a + bVal - (a * bVal) / -32768).round();
        } else if (a >= 0 && bVal >= 0) {
          mixed = (a + bVal - (a * bVal) / 32767).round();
        } else {
          mixed = a + bVal;
        }
        result[i] = mixed.clamp(-32768, 32767);
      }
    }
    return result;
  }

  /// Mixes a list of [Pcm16SoundBuffer]s using peak normalization.
  ///
  /// The method performs a two-pass mix: first, it computes the exact linear sum
  /// of all buffers. If the peak absolute value exceeds 32767, it scales all samples
  /// down proportionally to fit within the valid 16-bit range.
  static Pcm16SoundBuffer mixNormalized(Iterable<Pcm16SoundBuffer> buffers) {
    _validateBuffers(buffers);
    var list = buffers.toList();
    var first = list[0];
    var length = first.length;
    var sampleRate = first.sampleRate;

    // Pass 1: compute sums and find peak
    var sums = Float64List(length);
    var peak = 0.0;
    for (var i = 0; i < length; i++) {
      var sum = 0.0;
      for (var b in list) {
        sum += b[i];
      }
      sums[i] = sum;
      var absSum = sum.abs();
      if (absSum > peak) {
        peak = absSum;
      }
    }

    var result = Pcm16SoundBuffer(sampleRate, length);
    var scale = 1.0;
    if (peak > 32767.0) {
      scale = 32767.0 / peak;
    }

    // Pass 2: scale and write to result
    for (var i = 0; i < length; i++) {
      result[i] = (sums[i] * scale).round().clamp(-32768, 32767);
    }
    return result;
  }

  @override
  String toString() {
    return 'r $sampleRate size ${data.length}';
  }
}
