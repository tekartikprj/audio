# tekartik_wav

Reads and writes 16 bit PCM WAV files in pure Dart, and mixes PCM buffers.
Runs on the Dart VM, the web and Flutter (no plugin). Files go through
[fs_shim](https://pub.dev/packages/fs_shim), or you handle the bytes yourself.

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  tekartik_wav:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages/wav
```

```dart
import 'dart:math';

import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file.dart';
import 'package:tekartik_wav/wav_file_fs.dart';

Future<void> main() async {
  // One second of a 440 Hz sine, mono, 44.1 kHz: samples from -1 to 1.
  var sine = SoundBuffer(44100, 44100);
  for (var i = 0; i < sine.length; i++) {
    sine[i] = 0.5 * sin(2 * pi * 440 * i / 44100);
  }
  var bytes = writeWavBytes(
    sampleRate: 44100,
    numChannels: 1,
    soundBuffers: [sine],
  );

  // Read it back: from bytes, a file, an http response (any byte stream).
  var wav = await WavFile().read(Stream.value(bytes));
  print('${wav.numChannels} channel, ${wav.sampleRate} Hz, '
      '${wav.soundBuffers!.first.length} frames');
}
```

With a file system (`package:fs_shim/fs_shim.dart`: `fileSystemIo` on the VM
and Flutter native, `fileSystemWeb` on the web, `fileSystemMemory` in tests):

```dart
var wav = await WavFile().readFs(fileSystemIo, 'in.wav');
await wav.writeFs(fileSystemIo, 'copy.wav');
await mixWavFiles(fileSystemIo, ['a.wav', 'b.wav'], 'mix.wav');
```

A runnable example: [example/main.dart](example/main.dart).

## What to use

* `package:tekartik_wav/wav_file.dart`: `WavFile`. `read(stream)` parses a
  whole file; `feed(bytes)` parses chunk by chunk as they come.
  `soundBuffers` holds one `SoundBuffer` per channel (de-interleaved).
* `package:tekartik_wav/sound_utils.dart`: `SoundBuffer` (float samples,
  -1 to 1) and `Pcm16SoundBuffer` (int samples, -32768 to 32767), with 4 ways
  to mix buffers (`mixClamped`, `mixAverage`, `mixSoftClipped`,
  `mixNormalized`).
* `package:tekartik_wav/wav_file_fs.dart`: `writeWavBytes`, `readFs` /
  `writeFs` on an fs_shim `FileSystem`, `mixWavFiles` (file to file).
* `dart run tekartik_wav:wav_dump file.wav` prints the header of a file.

## Common mistakes

* Only uncompressed 16 bit PCM (format 1) is read. 8, 24, 32 bit, float,
  compressed and `WAVE_FORMAT_EXTENSIBLE` files (often used for more than 2
  channels) are a `FormatException`: convert them first (`ffmpeg -i in.wav
  -c:a pcm_s16le out.wav`).
* A truncated file (its data chunk shorter than its header says, a recording
  stopped before its header was written) is a `FormatException` for `read`.
  `feed` cannot know the end of the file: check that `soundBuffers` is not
  null once everything is fed.
* A `WavFile` reads one file: create a new one for the next file.
* `writeWavBytes` takes exactly `numChannels` buffers of the same length.
* Mixing needs the same sample rate everywhere (`ArgumentError` otherwise):
  resample first.
