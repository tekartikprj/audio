import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tekartik_wav/wav_file.dart';

import 'audio_input.dart';

/// Samples played as an input: a WAV file or computed sounds, in real time
/// (as the microphone would give them), faster, or as fast as possible.
class AudioInputSamples implements AudioInput {
  /// The mono samples.
  final Float32List samples;

  @override
  final int sampleRate;

  /// The speed: 1 in real time, 2 twice as fast, 0 as fast as possible.
  final double speed;

  /// The samples of a chunk.
  final int chunkSize;

  /// True to start again at the end, else the stream ends.
  final bool loop;

  StreamController<Float32List>? _controller;
  Timer? _timer;
  var _position = 0;

  /// [samples] at [sampleRate] Hz played at [speed] (0: as fast as
  /// possible) in chunks of [chunkSize], again and again when [loop].
  AudioInputSamples(
    this.samples, {
    required this.sampleRate,
    this.speed = 1,
    this.chunkSize = 1024,
    this.loop = false,
  }) : assert(chunkSize > 0);

  /// The samples of the WAV file [bytes] (16 bit PCM), its channels mixed
  /// to mono, played at [speed] in chunks of [chunkSize], again and again
  /// when [loop]. Throws a [FormatException] when [bytes] is not a
  /// supported WAV file.
  factory AudioInputSamples.wav(
    Uint8List bytes, {
    double speed = 1,
    int chunkSize = 1024,
    bool loop = false,
  }) {
    var wav = WavFile();
    try {
      wav.feed(bytes);
    } catch (e) {
      throw FormatException('not a supported WAV file: $e');
    }
    var buffers = wav.soundBuffers;
    var sampleRate = wav.sampleRate;
    if (buffers == null || buffers.isEmpty || sampleRate == null) {
      throw const FormatException('not a supported WAV file: no samples');
    }
    var length = buffers.fold(
      buffers.first.length,
      (min, buffer) => math.min(min, buffer.length),
    );
    var mono = Float32List(length);
    for (var buffer in buffers) {
      for (var i = 0; i < length; i++) {
        mono[i] += buffer.data[i] / buffers.length;
      }
    }
    return AudioInputSamples(
      mono,
      sampleRate: sampleRate,
      speed: speed,
      chunkSize: chunkSize,
      loop: loop,
    );
  }

  /// The duration of the samples, in seconds.
  double get duration => samples.length / sampleRate;

  @override
  double get latency => 0;

  /// True while started.
  bool get started => _controller != null;

  @override
  Future<Stream<Float32List>> start() async {
    await stop();
    _position = 0;
    var controller = _controller = StreamController<Float32List>();
    if (speed <= 0) {
      unawaited(_fast(controller));
    } else {
      var stopwatch = Stopwatch()..start();
      var sent = 0;
      void tick() {
        var due = stopwatch.elapsedMicroseconds * sampleRate * speed / 1e6;
        while (sent + chunkSize <= due && identical(_controller, controller)) {
          if (!_send(controller)) {
            return;
          }
          sent += chunkSize;
        }
      }

      _timer = Timer.periodic(const Duration(milliseconds: 10), (_) => tick());
    }
    return controller.stream;
  }

  Future<void> _fast(StreamController<Float32List> controller) async {
    while (identical(_controller, controller)) {
      if (!_send(controller)) {
        return;
      }
      // Lets the listeners run.
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Sends the next chunk; false once ended.
  bool _send(StreamController<Float32List> controller) {
    if (samples.isEmpty) {
      unawaited(stop());
      return false;
    }
    if (_position >= samples.length) {
      if (!loop) {
        unawaited(stop());
        return false;
      }
      _position = 0;
    }
    var chunk = Float32List(chunkSize);
    var filled = 0;
    while (filled < chunkSize) {
      var count = math.min(chunkSize - filled, samples.length - _position);
      chunk.setRange(filled, filled + count, samples, _position);
      filled += count;
      _position += count;
      if (_position >= samples.length) {
        if (!loop) {
          break;
        }
        _position = 0;
      }
    }
    controller.add(
      filled == chunkSize ? chunk : Float32List.sublistView(chunk, 0, filled),
    );
    return true;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    var controller = _controller;
    _controller = null;
    await controller?.close();
  }
}
