import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';

import 'processor.dart';
import 'protocol.dart';

/// The io processor: an isolate per session.
PitchWorkerProcessor newPitchWorkerProcessor({
  required String url,
  required bool fallback,
  required Duration startTimeout,
}) => _IoProcessor();

class _IoProcessor implements PitchWorkerProcessor {
  var _closed = false;
  final _sessions = <_IsolateSession>[];

  @override
  bool get offThread => true;

  @override
  Future<bool> get ready async => !_closed;

  @override
  Future<PitchSession> open(PitchRunner runner) async {
    if (_closed) {
      throw StateError('PitchWorkerProcessor closed');
    }
    var session = await _IsolateSession.spawn(runner);
    _sessions.add(session);
    return session;
  }

  @override
  Future<void> close() async {
    _closed = true;
    for (var session in _sessions.toList()) {
      await session.close();
    }
    _sessions.clear();
  }
}

/// The messages to the isolate: a chunk, the analyses, or null to close.
sealed class _Message {}

class _Chunk extends _Message {
  final TransferableTypedData samples;
  _Chunk(this.samples);
}

class _Analyses extends _Message {
  final List<PitchAnalysis> analyses;
  _Analyses(this.analyses);
}

/// From the isolate: a message failed, as the `error` of the web worker.
class _Failure {
  final String error;
  _Failure(this.error);
}

void _isolateMain((SendPort, PitchRunner) args) {
  var (out, runner) = args;
  var port = ReceivePort();
  out.send(port.sendPort);
  port.listen((message) {
    try {
      switch (message) {
        case _Chunk(:var samples):
          var steps = runner.add(samples.materialize().asFloat32List());
          if (steps.isNotEmpty) {
            out.send(steps);
          }
        case _Analyses(:var analyses):
          runner.analyses = analyses;
        default:
          port.close();
      }
    } catch (e) {
      out.send(_Failure('$e'));
    }
  });
}

class _IsolateSession implements PitchSession {
  _IsolateSession._(this._isolate, this._receive);

  final Isolate _isolate;
  final ReceivePort _receive;
  final _controller = StreamController<PitchStep>();
  final _port = Completer<SendPort>();
  var _closed = false;

  static Future<_IsolateSession> spawn(PitchRunner runner) async {
    var receive = ReceivePort();
    var isolate = await Isolate.spawn(_isolateMain, (
      receive.sendPort,
      runner,
    ), debugName: 'pitch session');
    var session = _IsolateSession._(isolate, receive);
    receive.listen(session._onMessage);
    return session;
  }

  void _onMessage(Object? message) {
    if (message is SendPort) {
      _port.complete(message);
    } else if (message is List && !_closed) {
      for (var step in message) {
        _controller.add(step as PitchStep);
      }
    } else if (message is _Failure && !_closed) {
      _controller.addError(PitchWorkerException(message.error));
    }
  }

  void _send(_Message message) {
    if (_closed) {
      return;
    }
    // In order, kept until the isolate answers with its port.
    unawaited(_port.future.then((port) => port.send(message)));
  }

  @override
  Stream<PitchStep> get steps => _controller.stream;

  @override
  void add(Float32List samples) =>
      _send(_Chunk(TransferableTypedData.fromList([samples])));

  @override
  void setAnalyses(List<PitchAnalysis> analyses) =>
      _send(_Analyses(List.of(analyses)));

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _isolate.kill();
    _receive.close();
    unawaited(_controller.close());
  }
}
