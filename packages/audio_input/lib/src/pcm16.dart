import 'dart:typed_data';

/// Turns little endian 16 bit PCM bytes into samples (-1 to 1), chunk by
/// chunk: a byte left over at the end of a chunk is kept for the next one.
class AudioInputPcm16Decoder {
  int? _pending;

  /// The samples of [bytes], with the byte left over from the previous
  /// chunk first.
  Float32List convert(Uint8List bytes) {
    var pending = _pending;
    var data = pending == null
        ? bytes
        : (Uint8List(bytes.length + 1)
            ..[0] = pending
            ..setRange(1, bytes.length + 1, bytes));
    var count = data.length ~/ 2;
    _pending = data.length.isOdd ? data.last : null;
    var view = ByteData.sublistView(data);
    var out = Float32List(count);
    for (var i = 0; i < count; i++) {
      out[i] = view.getInt16(2 * i, Endian.little) / 32768;
    }
    return out;
  }

  /// Forgets the byte left over (a new recording).
  void reset() => _pending = null;
}
