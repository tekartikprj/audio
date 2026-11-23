import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'audio_play.dart';

/// Plays sounds in a browser through Web Audio: an `AudioBufferSourceNode`
/// per sound on [context]'s destination.
///
/// Browsers start an `AudioContext` suspended until the user interacts with
/// the page: play the first sound from a click or a key press (it resumes
/// the context), or the play waits until there is one.
class AudioPlayWeb implements AudioPlay {
  web.AudioContext? _context;
  final _sources = <web.AudioBufferSourceNode>{};

  /// Plays on [context], by default an `AudioContext` created on the first
  /// play.
  AudioPlayWeb({this._context});

  /// The context the sounds play on.
  web.AudioContext get context => _context ??= web.AudioContext();

  @override
  Future<void> playSamples(
    List<Float32List> channels, {
    required int sampleRate,
  }) async {
    if (channels.isEmpty) {
      throw ArgumentError.value(channels, 'channels', 'no channel');
    }
    var buffer = context.createBuffer(
      channels.length,
      channels.first.length,
      sampleRate,
    );
    for (var i = 0; i < channels.length; i++) {
      buffer.copyToChannel(channels[i].toJS, i);
    }
    await _play(buffer);
  }

  @override
  Future<void> playWavBytes(Uint8List bytes) async {
    web.AudioBuffer buffer;
    try {
      // decodeAudioData detaches the buffer it gets: give it a copy.
      buffer = await context
          .decodeAudioData(Uint8List.fromList(bytes).buffer.toJS)
          .toDart;
    } catch (e) {
      throw AudioPlayException('Not a sound the browser decodes: $e');
    }
    await _play(buffer);
  }

  Future<void> _play(web.AudioBuffer buffer) async {
    var context = this.context;
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }
    var source = context.createBufferSource()..buffer = buffer;
    source.connect(context.destination);
    var ended = Completer<void>();
    source.onended = ((web.Event _) {
      if (!ended.isCompleted) {
        ended.complete();
      }
    }).toJS;
    _sources.add(source);
    source.start();
    try {
      await ended.future;
    } finally {
      _sources.remove(source);
      source.disconnect();
    }
  }

  @override
  Future<void> stop() async {
    for (var source in [..._sources]) {
      // Its `ended` event completes its play.
      source.stop();
    }
  }
}

/// The [AudioPlayWeb] of `audioPlay` in a browser.
final audioPlayWebDefault = AudioPlayWeb();
