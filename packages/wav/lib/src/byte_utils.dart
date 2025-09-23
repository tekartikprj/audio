import 'dart:math';
import 'dart:typed_data';

class _BaseBuffer {
  int index = 0;
  Uint8List data;

  _BaseBuffer(this.data);

  bool get done {
    return index >= data.length;
  }
}

class Reader extends _BaseBuffer {
  Reader(super.data);
}

class Filler extends _BaseBuffer {
  Filler(super.data);

  void fill(Reader reader) {
    if (!done) {
      var count = min(data.length - index, reader.data.length - reader.index);
      data.setRange(index, index + count, reader.data, reader.index);

      index += count;
      reader.index += count;
    }
  }
}

class Parser extends _BaseBuffer {
  Parser(super.data);

  void skip(int count) {
    index += count;
  }

  int readBEInt32() {
    var value = readBEInt16() << 16;
    value |= readBEInt16();
    return value;
  }

  int readLEInt32() {
    var value = readLEInt16();
    value |= readLEInt16() << 16;
    return value;
  }

  int readBEInt16() {
    var value = readInt8() << 8;
    value |= readInt8();
    return value;
  }

  int readLEInt16() {
    var value = readInt8();
    value |= readInt8() << 8;
    return value;
  }

  int readInt8() {
    var value = data[index++];
    return value;
  }

  static String int32asHex(int value) {
    var first = (value & 0xFFFF0000) >> 16;
    var second = value & 0xFFFF;
    return '${int16asHex(first)}${int16asHex(second)}';
  }

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

  static String int8asHex(int value) {
    var first = (value & 0xF0) >> 4;
    var second = value & 0x0F;
    return '${hex[first]}${hex[second]}';
  }

  static String int16asHex(int value) {
    var first = (value & 0xFF00) >> 8;
    var second = value & 0xFF;
    return '${int8asHex(first)}${int8asHex(second)}';
  }
}
