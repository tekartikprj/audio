import 'dart:typed_data';
import 'package:fs_shim/fs_shim.dart';
import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file.dart';

/// The algorithm to use for mixing WAV files.
enum WavMixAlgorithm {
  /// Sum the samples linearly and clamp to 16-bit range.
  clamped,

  /// Take the average of the samples.
  average,

  /// Use Viktor Toth's soft-clipping algorithm.
  softClipped,

  /// Perform a two-pass mix with peak normalization.
  normalized,
}

/// Extension on [WavFile] adding file system operations using [fs_shim].
extension WavFileFsExt on WavFile {
  /// Reads a WAV file from the given [path] using [fs].
  Future<WavFile> readFs(FileSystem fs, String path) async {
    var file = fs.file(path);
    return read(file.openRead());
  }

  /// Writes this [WavFile] to the given [path] using [fs].
  Future<void> writeFs(FileSystem fs, String path) async {
    if (soundBuffers == null || soundBuffers!.isEmpty) {
      throw StateError('WavFile must contain sound buffers to be written');
    }
    var bytes = writeWavBytes(
      sampleRate: sampleRate!,
      numChannels: numChannels!,
      soundBuffers: soundBuffers!,
    );
    await fs.file(path).writeAsBytes(bytes);
  }
}

/// Helper method to write a WAV file from [soundBuffers] directly.
Uint8List writeWavBytes({
  required int sampleRate,
  required int numChannels,
  required List<SoundBuffer> soundBuffers,
}) {
  if (soundBuffers.isEmpty) {
    throw ArgumentError('soundBuffers cannot be empty');
  }
  var count = soundBuffers[0].length;
  var subChunk2Size = count * numChannels * 2; // 16-bit = 2 bytes per sample
  var chunkSize = 36 + subChunk2Size;

  var byteData = ByteData(44 + subChunk2Size);

  // RIFF Header
  byteData.setUint8(0, 0x52); // R
  byteData.setUint8(1, 0x49); // I
  byteData.setUint8(2, 0x46); // F
  byteData.setUint8(3, 0x46); // F
  byteData.setUint32(4, chunkSize, Endian.little);
  byteData.setUint8(8, 0x57); // W
  byteData.setUint8(9, 0x41); // A
  byteData.setUint8(10, 0x56); // V
  byteData.setUint8(11, 0x45); // E

  // Subchunk 1 (fmt)
  byteData.setUint8(12, 0x66); // f
  byteData.setUint8(13, 0x6d); // m
  byteData.setUint8(14, 0x74); // t
  byteData.setUint8(15, 0x20); // ' '
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little); // PCM = 1
  byteData.setUint16(22, numChannels, Endian.little);
  byteData.setUint32(24, sampleRate, Endian.little);

  var bitsPerSample = 16;
  var byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
  var blockAlign = numChannels * (bitsPerSample ~/ 8);

  byteData.setUint32(28, byteRate, Endian.little);
  byteData.setUint16(32, blockAlign, Endian.little);
  byteData.setUint16(34, bitsPerSample, Endian.little);

  // Subchunk 2 (data)
  byteData.setUint8(36, 0x64); // d
  byteData.setUint8(37, 0x61); // a
  byteData.setUint8(38, 0x74); // t
  byteData.setUint8(39, 0x61); // a
  byteData.setUint32(40, subChunk2Size, Endian.little);

  var byteOffset = 44;
  for (var index = 0; index < count; index++) {
    for (var i = 0; i < numChannels; i++) {
      var doubleValue = soundBuffers[i][index];
      var intValue = (doubleValue * 32767).round().clamp(-32768, 32767);
      byteData.setInt16(byteOffset, intValue, Endian.little);
      byteOffset += 2;
    }
  }

  return byteData.buffer.asUint8List();
}

/// Mixes multiple WAV files into a single output WAV file.
///
/// Assumes all source files have the same sample rate. If they have differing
/// number of channels, the output will have the maximum number of channels among
/// all inputs, and shorter channels will be padded with silence.
Future<void> mixWavFiles(
  FileSystem fs,
  List<String> inputPaths,
  String outputPath, {
  WavMixAlgorithm algorithm = WavMixAlgorithm.clamped,
}) async {
  if (inputPaths.isEmpty) {
    throw ArgumentError('Input paths list cannot be empty');
  }

  var wavFiles = <WavFile>[];
  for (var path in inputPaths) {
    var wav = WavFile();
    await wav.readFs(fs, path);
    wavFiles.add(wav);
  }

  var sampleRate = wavFiles[0].sampleRate!;
  for (var wav in wavFiles) {
    if (wav.sampleRate != sampleRate) {
      throw ArgumentError('All files must have the same sample rate');
    }
  }

  var maxChannels = 0;
  for (var wav in wavFiles) {
    if (wav.numChannels! > maxChannels) {
      maxChannels = wav.numChannels!;
    }
  }

  var mixedChannels = <Pcm16SoundBuffer>[];
  for (var channelIdx = 0; channelIdx < maxChannels; channelIdx++) {
    var channelBuffersToMix = <Pcm16SoundBuffer>[];
    for (var wav in wavFiles) {
      if (channelIdx < wav.soundBuffers!.length) {
        var sb = wav.soundBuffers![channelIdx];
        channelBuffersToMix.add(Pcm16SoundBuffer.fromSoundBuffer(sb));
      } else {
        var length = wav.soundBuffers![0].length;
        var silentPcm = Pcm16SoundBuffer(sampleRate, length);
        channelBuffersToMix.add(silentPcm);
      }
    }

    Pcm16SoundBuffer mixedPcm;
    switch (algorithm) {
      case WavMixAlgorithm.clamped:
        mixedPcm = Pcm16SoundBuffer.mixClamped(channelBuffersToMix);
        break;
      case WavMixAlgorithm.average:
        mixedPcm = Pcm16SoundBuffer.mixAverage(channelBuffersToMix);
        break;
      case WavMixAlgorithm.softClipped:
        mixedPcm = Pcm16SoundBuffer.mixSoftClipped(channelBuffersToMix);
        break;
      case WavMixAlgorithm.normalized:
        mixedPcm = Pcm16SoundBuffer.mixNormalized(channelBuffersToMix);
        break;
    }
    mixedChannels.add(mixedPcm);
  }

  var mixedSoundBuffers = mixedChannels
      .map((pcm) => pcm.toSoundBuffer())
      .toList();

  var outputBytes = writeWavBytes(
    sampleRate: sampleRate,
    numChannels: maxChannels,
    soundBuffers: mixedSoundBuffers,
  );

  await fs.file(outputPath).writeAsBytes(outputBytes);
}
