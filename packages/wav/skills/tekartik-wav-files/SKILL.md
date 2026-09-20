---
name: tekartik-wav-files
description: >-
  Use when reading, writing or mixing 16-bit PCM wav files and pcm buffers in
  dart with tekartik_wav: WavFile (read, feed, soundBuffers, sampleRate,
  numChannels, bitsPerSample, dump), WavFileFsExt readFs/writeFs on a fs_shim
  FileSystem, writeWavBytes, mixWavFiles, WavMixAlgorithm, SoundBuffer and
  Pcm16SoundBuffer (mixClamped, mixAverage, mixSoftClipped, mixNormalized,
  toSoundBuffer, fromSoundBuffer) and the wav_dump command line tool.
---

# Wav files and pcm buffers (tekartik_wav)

`tekartik_wav` is a small, pure dart wav codec: an incremental reader for
uncompressed 16-bit PCM wav files, a byte writer, float and int16 sample
buffers, and four mixing algorithms. File access goes through `fs_shim`, so the
same code runs on the VM, in memory (tests) and on the web.

## Guidelines

* The package lives in a private repository and is not on pub.dev; depend on
  it from git:

  ```yaml
  dependencies:
    tekartik_wav:
      git:
        url: https://github.com/tekartikprj/audio
        path: packages/wav
  ```

* Three public libraries, import only what you need:
  * `package:tekartik_wav/wav_file.dart` → `WavFile` (parse/hold a wav file).
  * `package:tekartik_wav/sound_utils.dart` → `SoundBuffer`,
    `Pcm16SoundBuffer` (raw pcm channels, no file involved).
  * `package:tekartik_wav/wav_file_fs.dart` → `WavFileFsExt` (`readFs`,
    `writeFs`), `writeWavBytes`, `mixWavFiles`, `WavMixAlgorithm`. Needs
    `package:fs_shim/fs_shim.dart` for the `FileSystem` (`fileSystemIo`,
    `fileSystemMemory`).
* Supported format: RIFF/WAVE, `audioFormat` 1 (uncompressed PCM) with
  `bitsPerSample` 16 only. Anything else (compressed, 8/24/32-bit, float)
  throws a `FormatException` while parsing, and so does a broken `RIFF`,
  `WAVE`, `fmt ` or `data` marker. Convert first (ffmpeg) rather than trying
  to extend the parser at call site.
* Reading: `var wav = WavFile(); await wav.read(stream);` where `stream` is a
  `Stream<List<int>>` (`file.openRead()`, an http response body...).
  `WavFile.feed(Uint8List)` is the synchronous entry point when the bytes
  arrive by hand; it is incremental, so a header split across two chunks is
  fine. `readFs(fs, path)` is `read(fs.file(path).openRead())`.
* After a successful read: `sampleRate`, `numChannels`, `bitsPerSample`,
  `audioFormat`, `totalChunkSize` and `soundBuffers` are set. They are all
  nullable (they are `null` on a fresh `WavFile`), so read them with `!` only
  once the read future completed. `dump()` prints them for debugging.
* `soundBuffers` is one `SoundBuffer` per channel, already de-interleaved
  (mono = 1 buffer, stereo = `[left, right]`), with samples as doubles in
  `[-1.0, 1.0[` (the reader divides by 32768, the writer multiplies by 32767
  and clamps). Never interleave or de-interleave samples yourself.
* Writing: build a `WavFile()` and set the three fields
  (`..sampleRate = 44100 ..numChannels = 1 ..soundBuffers = [sb]`), then
  `await wav.writeFs(fs, path)` — it throws `StateError` when `soundBuffers`
  is null or empty. To get the bytes without a file system (flutter download,
  http response, in-memory test) call `writeWavBytes(sampleRate:,
  numChannels:, soundBuffers:)`, which returns a `Uint8List` of
  `44 + frames * numChannels * 2` bytes and throws `ArgumentError` on an empty
  list.
* `writeWavBytes` takes the frame count from `soundBuffers[0].length` and
  reads `numChannels` buffers: give it exactly `numChannels` buffers, all of
  the same length, or it will range-error or silently truncate.
* `SoundBuffer(sampleRate, length)` allocates a `Float32List`;
  `SoundBuffer.fromData(sampleRate, Float32List)` wraps existing data and
  `SoundBuffer.view(other, index, count)` is a zero-copy window into another
  buffer. Sample access is `sb[i]` / `sb[i] = value`, plus `length`,
  `shiftBy(count)` (shift the data left in place) and `average(index, count)`.
  `sampleRate` is a `num`.
* `Pcm16SoundBuffer` is the same buffer over an `Int16List` in
  `[-32768, 32767]`: convert with `Pcm16SoundBuffer.fromSoundBuffer(sb)`
  (clamps to `[-1.0, 1.0]`) and `pcm.toSoundBuffer()`.
* Mixing happens on `Pcm16SoundBuffer` static methods, each taking an
  `Iterable<Pcm16SoundBuffer>` (one channel of each source) and returning a
  buffer of the longest input length: `mixClamped` (linear sum then clamp:
  loudest, can distort), `mixAverage` (no clipping, quieter with every extra
  source), `mixSoftClipped` (non-linear, loud and clip free) and
  `mixNormalized` (exact sum, scaled down only when the peak exceeds full
  scale). They throw `ArgumentError` on an empty iterable or when the sample
  rates differ.
* `mixWavFiles(fs, inputPaths, outputPath, algorithm: WavMixAlgorithm.clamped)`
  does the whole file-to-file job: all inputs must share the sample rate
  (`ArgumentError` otherwise), the output gets the maximum channel count of
  the inputs (missing channels are mixed as silence) and the maximum length.
  `WavMixAlgorithm` values map one to one to the `Pcm16SoundBuffer.mix*`
  methods: `clamped`, `average`, `softClipped`, `normalized`.
* `dart run tekartik_wav:wav_dump <file.wav>...` (`bin/wav_dump.dart`) parses
  each file and prints its header — the quickest way to check that a file is
  in the supported subset.
* Testing: use `fileSystemMemory` from `package:fs_shim/fs_shim.dart`, write a
  file and read it back; expect a 16-bit round trip, so compare samples with
  `closeTo(value, 0.001)`, not `equals`. Tests that touch real files are
  `@TestOn('vm')`.
* Anti-patterns: touching `soundBuffers!` before awaiting `read`; reusing one
  `WavFile` instance to parse two files (the parser keeps its state — build a
  new one); mixing buffers with different sample rates (resample first);
  assuming a wav found in the wild is 16-bit PCM.

## Examples

Read a wav file from disk and print what it contains.

```dart
import 'package:fs_shim/fs_shim.dart';
import 'package:tekartik_wav/wav_file.dart';
import 'package:tekartik_wav/wav_file_fs.dart';

Future<void> main(List<String> args) async {
  var wav = WavFile();
  await wav.readFs(fileSystemIo, args.first);

  var channels = wav.soundBuffers!;
  var frameCount = channels.first.length;
  print('${wav.numChannels} channel(s) at ${wav.sampleRate}Hz, '
      '${wav.bitsPerSample} bits, $frameCount frames, '
      '${(frameCount / wav.sampleRate!).toStringAsFixed(2)}s');
  print('peak ${channels.first.data.reduce((a, b) => a.abs() > b.abs() ? a : b)}');
}
```

Generate a mono sine wave and write it, both as a file and as raw bytes.

```dart
import 'dart:math';
import 'dart:typed_data';

import 'package:fs_shim/fs_shim.dart';
import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file.dart';
import 'package:tekartik_wav/wav_file_fs.dart';

SoundBuffer sine({int sampleRate = 44100, double freq = 440, double s = 1}) {
  var buffer = SoundBuffer(sampleRate, (sampleRate * s).round());
  for (var i = 0; i < buffer.length; i++) {
    buffer[i] = sin(2 * pi * freq * i / sampleRate) * 0.5;
  }
  return buffer;
}

Future<void> main() async {
  var buffer = sine(freq: 440);

  // Straight to a file (fileSystemIo, fileSystemMemory in tests).
  var wav = WavFile()
    ..sampleRate = 44100
    ..numChannels = 1
    ..soundBuffers = [buffer];
  await wav.writeFs(fileSystemIo, 'a440.wav');

  // Or just the bytes, for an http response or a flutter download.
  Uint8List bytes = writeWavBytes(
    sampleRate: 44100,
    numChannels: 1,
    soundBuffers: [buffer],
  );
  print('${bytes.length} bytes');
}
```

Mix wav files together, file to file.

```dart
import 'package:fs_shim/fs_shim.dart';
import 'package:tekartik_wav/wav_file_fs.dart';

Future<void> main(List<String> args) async {
  // All inputs must share the sample rate; the output takes the largest
  // channel count and the longest duration.
  await mixWavFiles(
    fileSystemIo,
    ['drums.wav', 'bass.wav', 'voice.wav'],
    'mix.wav',
    algorithm: WavMixAlgorithm.normalized,
  );
}
```

Mix pcm channels in memory, without any file.

```dart
import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file_fs.dart';

/// Mixes [tracks] (one mono [SoundBuffer] each) into wav bytes.
List<int> mixMonoTracks(List<SoundBuffer> tracks, {int sampleRate = 44100}) {
  var pcmTracks = tracks.map(Pcm16SoundBuffer.fromSoundBuffer).toList();
  var mixed = Pcm16SoundBuffer.mixSoftClipped(pcmTracks);
  return writeWavBytes(
    sampleRate: sampleRate,
    numChannels: 1,
    soundBuffers: [mixed.toSoundBuffer()],
  );
}

void main() {
  var silence = SoundBuffer(44100, 44100);
  print(mixMonoTracks([silence, silence]).length);
}
```

Parse wav bytes that arrive chunk by chunk (no file system at all).

```dart
import 'dart:typed_data';

import 'package:tekartik_wav/wav_file.dart';

/// Parses a wav from an already downloaded [bytes] buffer.
WavFile parseWavBytes(Uint8List bytes) {
  var wav = WavFile();
  // feed() is incremental: any chunking works, here 4kB at a time.
  for (var offset = 0; offset < bytes.length; offset += 4096) {
    var end = (offset + 4096).clamp(0, bytes.length);
    wav.feed(Uint8List.sublistView(bytes, offset, end));
  }
  return wav;
}

Future<WavFile> parseWavStream(Stream<List<int>> stream) async {
  return WavFile().read(stream);
}
```
