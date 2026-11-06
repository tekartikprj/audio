import 'dart:typed_data';

/// A source of mono samples (-1 to 1): a microphone, a file, a test.
abstract class AudioInput {
  /// The sample rate of the chunks, in Hz.
  int get sampleRate;

  /// About how late the samples come, in seconds (the capture, the
  /// buffers); 0 for a file or a test.
  double get latency;

  /// Starts: the samples, chunk by chunk (any size). Throws
  /// [AudioInputDenied] when not allowed, [AudioInputUnavailable] when
  /// there is no input or it failed.
  Future<Stream<Float32List>> start();

  /// Stops: the stream of [start] ends.
  Future<void> stop();
}

/// The states of an audio input as shown to the user.
enum AudioInputState {
  /// Not started.
  off,

  /// Starting (asking for the microphone).
  starting,

  /// Giving samples.
  on,

  /// Not allowed by the user or the platform.
  denied,

  /// No input, or it failed.
  failed,
}

/// The input was not allowed (the microphone permission).
class AudioInputDenied implements Exception {
  /// Why, when known.
  final String? message;

  /// Not allowed, [message] telling why when known.
  const AudioInputDenied([this.message]);

  @override
  String toString() => 'AudioInputDenied${message == null ? '' : ': $message'}';
}

/// There is no input, or it failed.
class AudioInputUnavailable implements Exception {
  /// Why, when known.
  final String? message;

  /// No input, [message] telling why when known.
  const AudioInputUnavailable([this.message]);

  @override
  String toString() =>
      'AudioInputUnavailable${message == null ? '' : ': $message'}';
}
