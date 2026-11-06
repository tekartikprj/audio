import 'dart:async';
import 'dart:typed_data';

import 'audio_input.dart';

/// An input fed by hand ([push]): tests, demos, samples coming from
/// elsewhere.
class AudioInputPush implements AudioInput {
  @override
  final int sampleRate;

  @override
  final double latency;

  StreamController<Float32List>? _controller;

  /// An input at [sampleRate] Hz, [latency] seconds late.
  AudioInputPush({this.sampleRate = 44100, this.latency = 0});

  /// True while started.
  bool get started => _controller != null;

  @override
  Future<Stream<Float32List>> start() async {
    await _controller?.close();
    var controller = _controller = StreamController<Float32List>();
    return controller.stream;
  }

  /// Gives [samples] to the stream (ignored when not started).
  void push(Float32List samples) => _controller?.add(samples);

  @override
  Future<void> stop() async {
    var controller = _controller;
    _controller = null;
    await controller?.close();
  }
}
