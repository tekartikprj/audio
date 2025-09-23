import 'dart:async';
import 'dart:typed_data';

import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/src/import.dart';

import 'byte_utils.dart';

/// Represents a WAV audio file and provides methods to read and parse it.
class WavFile {
  /// The list of sound buffers parsed from the WAV file.
  List<SoundBuffer>? soundBuffers;

  /// Constructs a [WavFile] and initializes the header filler.
  WavFile() {
    headerFiller = Filler(header);
  }

  /// Reads the WAV file from a [stream].
  ///
  /// Returns this [WavFile] after reading.
  Future<WavFile> read(Stream<List<int>> stream) async {
    await stream.listen((List<int> data) {
      //print(data);
      //subscription
      feed(asUint8List(data));
    }).asFuture<void>();
    return this;
  }

  /// Whether the header has been read.
  bool? headerRead;

  /// Whether the file has been fully read.
  var _done = false;

  /// The header bytes (first 12 bytes of the file).
  Uint8List header = Uint8List(12);

  /// Filler for the header buffer.
  late Filler headerFiller;

  /// The current chunk data being read.
  Uint8List? chunk;

  /// Filler for the current chunk.
  late Filler chunkFiller;

  /// The current chunk header data.
  late Uint8List chunkHeader;

  /// Filler for the current chunk header.
  Filler? chunkHeaderFiller;

  /// The total chunk size (file size minus 8 bytes).
  int? totalChunkSize;

  /// The current chunk size.
  int? chunkSize;

  /// The audio format code.
  int? audioFormat;

  /// The number of channels in the audio (e.g., 1 for mono, 2 for stereo).
  int? numChannels;

  /// The sample rate of the audio in Hz.
  int? sampleRate;

  /// The number of bits per sample.
  int? bitsPerSample;

  bool _fmtChunkDone = false;

  void _throwBadFormat(String text) {
    throw FormatException(text);
  }

  void _checkHeader() {
    if (headerFiller.done) {
      // check header
      // RIFF
      var parser = Parser(header);
      var riff = parser.readBEInt32();
      if (riff != 0x52494646) {
        // 'RIFF'
        _throwBadFormat("invalid 'RIFF' header ${Parser.int32asHex(riff)}");
      }
      totalChunkSize = parser.readLEInt32();
      var wave = parser.readBEInt32();
      if (wave != 0x57415645) {
        // 'WAVE'
        _throwBadFormat("invalid 'WAVE' header ${Parser.int32asHex(wave)}");
      }
    }
  }

  void _checkFmtChunkHeader() {
    if (chunkHeaderFiller!.done) {
      // check header
      // fmt
      var parser = Parser(chunkHeader);
      var fmt = parser.readBEInt32();
      if (fmt != 0x666d7420) {
        // 'fmt '
        _throwBadFormat("invalid 'fmt ' header ${Parser.int32asHex(fmt)}");
      }
      chunkSize = parser.readLEInt32();
    }
  }

  void _checkDataChunkHeader() {
    if (chunkHeaderFiller!.done) {
      // check header
      // fmt
      var parser = Parser(chunkHeader);
      var data = parser.readBEInt32();
      if (data != 0x64617461) {
        // 'data'
        _throwBadFormat("invalid 'data' header ${Parser.int32asHex(data)}");
      }
      chunkSize = parser.readLEInt32();
    }
  }

  void _parseFmtChunk() {
    //    20        2   AudioFormat      PCM = 1 (i.e. Linear quantization)
    //        Values other than 1 indicate some
    //        form of compression.
    //        22        2   NumChannels      Mono = 1, Stereo = 2, etc.
    //        24        4   SampleRate       8000, 44100, etc.
    //        28        4   ByteRate         == SampleRate * NumChannels * BitsPerSample/8
    //        32        2   BlockAlign       == NumChannels * BitsPerSample/8
    //        The number of bytes for one sample including
    //        all channels. I wonder what happens when
    //        this number isn't an integer?
    //            34        2   BitsPerSample    8 bits = 8, 16 bits = 16, etc.
    var parser = Parser(chunk!);
    audioFormat = parser.readLEInt16();
    numChannels = parser.readLEInt16();
    sampleRate = parser.readLEInt32();
    parser.skip(6); // byte rate, block align
    bitsPerSample = parser.readLEInt16();

    if (audioFormat != 1) {
      _throwBadFormat('uncompress PCM only');
    }
    if (bitsPerSample != 16) {
      _throwBadFormat('16bits only');
    }
  }

  void _parseDataChunk() {
    var parser = Parser(chunk!);

    var count = parser.data.length ~/ (bitsPerSample! / 8) ~/ numChannels!;

    soundBuffers = List<SoundBuffer>.generate(numChannels!, (i) {
      var sb = SoundBuffer(sampleRate!, count);
      return sb;
    });

    for (var index = 0; index < count; index++) {
      for (var i = 0; i < numChannels!; i++) {
        var value = parser.readLEInt16();
        if (value > 32767) {
          value = -(65536 - value);
        }
        soundBuffers![i][index] = value.toDouble() / 32768;
      }
    }
  }

  /// Feeds a chunk of [data] to the WAV file parser.
  void feed(Uint8List data) {
    var reader = Reader(data);

    // int inIndex = 0;

    if (!headerFiller.done) {
      headerFiller.fill(reader);
      _checkHeader();
      if (!headerFiller.done) {
        return;
      }
    }
    //    // check header
    //    if (index < header.length) {
    //      // fill up to 12
    //      int count = min(header.length - index, data.length);
    //      header.setRange(index, count, data);
    //      index += count;
    //
    //      _checkHeader();
    //    }

    if (!_fmtChunkDone) {
      // Chunk1 header

      if (chunkHeaderFiller == null) {
        chunkHeader = Uint8List(8);
        chunkHeaderFiller = Filler(chunkHeader);
      }

      if (!chunkHeaderFiller!.done) {
        chunkHeaderFiller!.fill(reader);
        _checkFmtChunkHeader();
        if (!chunkHeaderFiller!.done) {
          return;
        }
      }

      // Chunk1 creation
      if (chunk == null) {
        chunk = Uint8List(chunkSize!);
        chunkFiller = Filler(chunk!);
      }

      // Chunk1
      if (!chunkFiller.done) {
        chunkFiller.fill(reader);
        if (chunkFiller.done) {
          _parseFmtChunk();
        } else {
          return;
        }

        _fmtChunkDone = true;

        // Reset for 'data'
        chunkHeaderFiller = null;
      }
    }

    if (_fmtChunkDone) {
      // Channel data

      if (chunkHeaderFiller == null) {
        chunkHeader = Uint8List(8);
        chunkHeaderFiller = Filler(chunkHeader);
      }

      if (!chunkHeaderFiller!.done) {
        chunkHeaderFiller!.fill(reader);
        _checkDataChunkHeader();
        if (!chunkHeaderFiller!.done) {
          return;
        }

        // reset chunk
        chunk = null;
      }

      // Chunk2 creation
      if (chunk == null) {
        chunk = Uint8List(chunkSize!);
        chunkFiller = Filler(chunk!);
      }

      // Chunk2
      if (!chunkFiller.done) {
        chunkFiller.fill(reader);
        if (chunkFiller.done) {
          _parseDataChunk();
        } else {
          return;
        }
      }

      _done = true;
    }
  }

  /// Dumps the internal state of the WAV file for debugging purposes.
  void dump() {
    void log(Object? message) {
      // ignore: avoid_print
      print(message);
    }

    // ignore: avoid_print
    log('audioFormat: $audioFormat');
    log('numChannels: $numChannels');
    log('sampleRate: $sampleRate');
    log('bitsPerSample: $bitsPerSample');
    log('totalChunkSize: $totalChunkSize');

    log(soundBuffers);

    if (!chunkFiller.done) {
      log('${chunkFiller.data.length} read while ${chunkFiller.index} found');
    }

    //    soundBuffers.forEach((SoundBuffer buffer) {
    //      print(buffer);
    //    });
    //       if (ppq != null) {
    //         print('ppq: $ppq');
    //       } else {
    //         print('framesPerSecond: $frameCountPerSecond');
    //         print('divisionsPerFrame: $divisionCountPerFrame');
    //       }
    //       int index = 0;
    //       tracks.forEach((MidiTrack track) {
    //         print('Track ${++index}');
    //         track.dump();
    //       });
    //    int audioFormat;
    //     int numChannels;
    //     int sampleRate;
    //     int bitsPerSample;
  }
}

/// Private extension
extension WavFilePrvExt on WavFile {
  /// Whether the file has been fully read.
  bool get done => _done;
}
