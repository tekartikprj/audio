import 'dart:async';
import 'dart:typed_data';

import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/src/import.dart';

import 'byte_utils.dart';

class WavFile {
  //StreamS

  List<SoundBuffer>? soundBuffers;

  WavFile() {
    headerFiller = Filler(header);
  }

  // Ingore return value, only here for compatibility
  Future<WavFile> read(Stream<List<int>> stream) async {
    await stream.listen((List<int> data) {
      //print(data);
      //subscription
      feed(asUint8List(data));
    }).asFuture<void>();
    return this;
  }

  bool? headerRead;
  bool done = false;
  Uint8List header = Uint8List(12);
  late Filler headerFiller;

  Uint8List? chunk;
  late Filler chunkFiller;

  late Uint8List chunkHeader;
  Filler? chunkHeaderFiller;

  //  36 + SubChunk2Size, or more precisely:
  //    4 + (8 + SubChunk1Size) + (8 + SubChunk2Size)
  //    This is the size of the rest of the chunk
  //    following this number.  This is the size of the
  //    entire file in bytes minus 8 bytes for the
  //    two fields not included in this count:
  //      ChunkID and ChunkSize.
  int? totalChunkSize;
  int? chunkSize;

  // Format
  int? audioFormat;
  int? numChannels;
  int? sampleRate;
  int? bitsPerSample;

  bool fmtChunkDone = false;

  void throwBadFormat(String text) {
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
        throwBadFormat("invalid 'RIFF' header ${Parser.int32asHex(riff)}");
      }
      totalChunkSize = parser.readLEInt32();
      var wave = parser.readBEInt32();
      if (wave != 0x57415645) {
        // 'WAVE'
        throwBadFormat("invalid 'WAVE' header ${Parser.int32asHex(wave)}");
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
        throwBadFormat("invalid 'fmt ' header ${Parser.int32asHex(fmt)}");
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
        throwBadFormat("invalid 'data' header ${Parser.int32asHex(data)}");
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
      throwBadFormat('uncompress PCM only');
    }
    if (bitsPerSample != 16) {
      throwBadFormat('16bits only');
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

    if (!fmtChunkDone) {
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

        fmtChunkDone = true;

        // Reset for 'data'
        chunkHeaderFiller = null;
      }
    }

    if (fmtChunkDone) {
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

      done = true;
    }
  }

  void dump() {
    print('audioFormat: $audioFormat');
    print('numChannels: $numChannels');
    print('sampleRate: $sampleRate');
    print('bitsPerSample: $bitsPerSample');
    print('totalChunkSize: $totalChunkSize');

    print(soundBuffers);

    if (!chunkFiller.done) {
      print('${chunkFiller.data.length} read while ${chunkFiller.index} found');
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
