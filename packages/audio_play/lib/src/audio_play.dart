import 'dart:typed_data';

import 'package:tekartik_wav/sound_utils.dart';
import 'package:tekartik_wav/wav_file_fs.dart';

/// Plays sounds; each play completes when its sound ends, or when [stop]
/// is called. Several sounds may play at once.
///
/// `AudioPlayIo` (`audio_play_io.dart`) plays them through a player of the
/// host (VM), `AudioPlayWeb` (`audio_play_web.dart`) through Web Audio.
abstract class AudioPlay {
  /// Plays [bytes], a whole WAV file (16 bit PCM at least; the web reads
  /// what the browser decodes).
  Future<void> playWavBytes(Uint8List bytes);

  /// Plays [channels] (one list of samples from -1 to 1 per channel, all
  /// of the same length) at [sampleRate] Hz.
  Future<void> playSamples(
    List<Float32List> channels, {
    required int sampleRate,
  });

  /// Stops every sound playing; their plays complete without error.
  Future<void> stop();
}

/// A sound that could not be played: no player found, a player that failed,
/// bytes that are not a sound.
class AudioPlayException implements Exception {
  /// What went wrong, in English.
  final String message;

  /// An exception of [message].
  AudioPlayException(this.message);

  @override
  String toString() => 'AudioPlayException: $message';
}

/// The WAV file (16 bit PCM) of [channels] (samples from -1 to 1, one list
/// per channel, all of the same length) at [sampleRate] Hz.
Uint8List audioSamplesToWavBytes(
  List<Float32List> channels, {
  required int sampleRate,
}) {
  if (channels.isEmpty) {
    throw ArgumentError.value(channels, 'channels', 'no channel');
  }
  return writeWavBytes(
    sampleRate: sampleRate,
    numChannels: channels.length,
    soundBuffers: [
      for (var channel in channels) SoundBuffer.fromData(sampleRate, channel),
    ],
  );
}
