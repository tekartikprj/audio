import 'dart:async';
import 'dart:typed_data';

import 'audio_input.dart';
import 'level.dart';

/// Any [AudioInput] with its level measured as the samples go through:
/// the analysis (or recording) uses it as the input, a meter shows
/// [levels] or [level], independently.
class AudioInputMetered implements AudioInput {
  /// The input measured.
  final AudioInput input;

  /// The meter settings (the sample rate of [input] is used).
  final double releaseDecibelsPerSecond;

  /// How long a peak is held, in seconds.
  final double peakHoldSeconds;

  final _levels = StreamController<AudioLevel>.broadcast(sync: true);
  AudioLevelMeter? _meter;
  var _level = AudioLevel.silence;

  /// [input] measured, the displayed level falling at
  /// [releaseDecibelsPerSecond], peaks held [peakHoldSeconds].
  AudioInputMetered(
    this.input, {
    this.releaseDecibelsPerSecond = 24,
    this.peakHoldSeconds = 1.5,
  });

  @override
  int get sampleRate => input.sampleRate;

  @override
  double get latency => input.latency;

  /// The level of each chunk going through (silence when stopped).
  Stream<AudioLevel> get levels => _levels.stream;

  /// The last level ([AudioLevel.silence] when stopped).
  AudioLevel get level => _level;

  void _emit(AudioLevel level) {
    _level = level;
    if (!_levels.isClosed) {
      _levels.add(level);
    }
  }

  @override
  Future<Stream<Float32List>> start() async {
    var meter = _meter = AudioLevelMeter(
      sampleRate: input.sampleRate,
      releaseDecibelsPerSecond: releaseDecibelsPerSecond,
      peakHoldSeconds: peakHoldSeconds,
    );
    var chunks = await input.start();
    return chunks.map((chunk) {
      if (identical(meter, _meter)) {
        _emit(meter.add(chunk));
      }
      return chunk;
    });
  }

  @override
  Future<void> stop() async {
    _meter = null;
    await input.stop();
    _emit(AudioLevel.silence);
  }

  /// Closes [levels].
  Future<void> close() => _levels.close();
}
