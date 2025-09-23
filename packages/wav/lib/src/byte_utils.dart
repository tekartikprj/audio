import 'dart:math';
import 'dart:typed_data';

/// Base buffer class for managing byte data and index.
class _BaseBuffer {
  /// Current index in the buffer.
  int index = 0;

  /// Underlying byte data.
  Uint8List data;

  /// Constructs a [_BaseBuffer] with the given [data].
  _BaseBuffer(this.data);

  /// Returns true if the buffer has been fully read or filled.
  bool get done {
    return index >= data.length;
  }
}

/// A buffer for reading bytes.
class Reader extends _BaseBuffer {
  /// Constructs a [Reader] with the given [data].
  Reader(super.data);
}

/// A buffer for filling bytes from another buffer.
class Filler extends _BaseBuffer {
  /// Constructs a [Filler] with the given [data].
  Filler(super.data);

  /// Fills this buffer with data from [reader].
  void fill(Reader reader) {
    if (!done) {
      var count = min(data.length - index, reader.data.length - reader.index);
      data.setRange(index, index + count, reader.data, reader.index);

      index += count;
      reader.index += count;
    }
  }
}

/// A buffer for parsing bytes with utility methods for reading integers.
class Parser extends _BaseBuffer {
  /// Constructs a [Parser] with the given [data].
  Parser(super.data);

  /// Skips [count] bytes in the buffer.
  void skip(int count) {
    index += count;
  }

  /// Reads a 32-bit big-endian integer from the buffer.
  int readBEInt32() {
    var value = readBEInt16() << 16;
    value |= readBEInt16();
    return value;
  }

  /// Reads a 32-bit little-endian integer from the buffer.
  int readLEInt32() {
    var value = readLEInt16();
    value |= readLEInt16() << 16;
    return value;
  }

  /// Reads a 16-bit big-endian integer from the buffer.
  int readBEInt16() {
    var value = readInt8() << 8;
    value |= readInt8();
    return value;
  }

  /// Reads a 16-bit little-endian integer from the buffer.
  int readLEInt16() {
    var value = readInt8();
    value |= readInt8() << 8;
    return value;
  }

  /// Reads an 8-bit integer from the buffer.
  int readInt8() {
    var value = data[index++];
    return value;
  }

  /// Converts a 32-bit integer [value] to a hexadecimal string.
  static String int32asHex(int value) {
    var first = (value & 0xFFFF0000) >> 16;
    var second = value & 0xFFFF;
    return '${int16asHex(first)}${int16asHex(second)}';
  }

  /// Hexadecimal digit lookup table.
  static List<String> hex = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
  ];

  /// Converts an 8-bit integer [value] to a hexadecimal string.
  static String int8asHex(int value) {
    var first = (value & 0xF0) >> 4;
    var second = value & 0x0F;
    return '${hex[first]}${hex[second]}';
  }

  /// Converts a 16-bit integer [value] to a hexadecimal string.
  static String int16asHex(int value) {
    var first = (value & 0xFF00) >> 8;
    var second = value & 0xFF;
    return '${int8asHex(first)}${int8asHex(second)}';
  }
}
