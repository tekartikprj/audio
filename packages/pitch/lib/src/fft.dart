import 'dart:math' as math;
import 'dart:typed_data';

/// A complex FFT of a power of two [size], in place, its tables computed
/// once per size and kept.
class PitchFft {
  /// The number of complex points.
  final int size;

  final Float64List _cos;
  final Float64List _sin;
  final Int32List _reversed;

  static final _cache = <int, PitchFft>{};

  PitchFft._(this.size)
    : _cos = Float64List(size ~/ 2),
      _sin = Float64List(size ~/ 2),
      _reversed = Int32List(size) {
    for (var i = 0; i < size ~/ 2; i++) {
      var angle = -2 * math.pi * i / size;
      _cos[i] = math.cos(angle);
      _sin[i] = math.sin(angle);
    }
    var bits = 0;
    while ((1 << bits) < size) {
      bits++;
    }
    for (var i = 0; i < size; i++) {
      var reversed = 0;
      for (var bit = 0; bit < bits; bit++) {
        if (i & (1 << bit) != 0) {
          reversed |= 1 << (bits - 1 - bit);
        }
      }
      _reversed[i] = reversed;
    }
  }

  /// The FFT of [size] points; throws an [ArgumentError] when [size] is not
  /// a power of two of at least 2.
  factory PitchFft(int size) {
    if (size < 2 || size & (size - 1) != 0) {
      throw ArgumentError.value(size, 'size', 'not a power of two');
    }
    return _cache.putIfAbsent(size, () => PitchFft._(size));
  }

  /// True when [size] is a power of two of at least 2.
  static bool isPowerOfTwo(int size) => size >= 2 && size & (size - 1) == 0;

  /// The smallest power of two at least [value] (and at least [minimum]).
  static int powerOfTwoAtLeast(num value, {int minimum = 2}) {
    var size = minimum;
    while (size < value) {
      size *= 2;
    }
    return size;
  }

  /// Transforms the complex points ([re], [im], both of [size]) in place;
  /// the [inverse] transform is scaled by 1 / [size].
  void transform(Float64List re, Float64List im, {bool inverse = false}) {
    var n = size;
    for (var i = 0; i < n; i++) {
      var j = _reversed[i];
      if (j > i) {
        var t = re[i];
        re[i] = re[j];
        re[j] = t;
        t = im[i];
        im[i] = im[j];
        im[j] = t;
      }
    }
    var sign = inverse ? -1.0 : 1.0;
    for (var half = 1; half < n; half <<= 1) {
      var step = n ~/ (half * 2);
      for (var start = 0; start < n; start += half * 2) {
        for (var k = 0; k < half; k++) {
          var wr = _cos[k * step];
          var wi = sign * _sin[k * step];
          var a = start + k;
          var b = a + half;
          var xr = re[b] * wr - im[b] * wi;
          var xi = re[b] * wi + im[b] * wr;
          re[b] = re[a] - xr;
          im[b] = im[a] - xi;
          re[a] += xr;
          im[a] += xi;
        }
      }
    }
    if (inverse) {
      for (var i = 0; i < n; i++) {
        re[i] /= n;
        im[i] /= n;
      }
    }
  }
}
