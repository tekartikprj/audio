import 'dart:typed_data';

import 'audio_play.dart';
import 'platform/audio_play_platform_stub.dart'
    if (dart.library.io) 'platform/audio_play_platform_io.dart'
    if (dart.library.js_interop) 'platform/audio_play_platform_web.dart';

/// The player of this platform: an `AudioPlayIo` on the VM (the first
/// player of the host found, the default sink), an `AudioPlayWeb` in a
/// browser.
AudioPlay get audioPlay => audioPlayPlatform;

/// Plays [bytes], a whole WAV file, with [audioPlay].
Future<void> audioPlayWavBytes(Uint8List bytes) =>
    audioPlay.playWavBytes(bytes);

/// Plays [channels] (samples from -1 to 1, one list per channel) at
/// [sampleRate] Hz with [audioPlay].
Future<void> audioPlaySamples(
  List<Float32List> channels, {
  required int sampleRate,
}) => audioPlay.playSamples(channels, sampleRate: sampleRate);
