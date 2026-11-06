import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:tekartik_pitch/pitch.dart';
import 'package:web/web.dart' as web;

import 'js_message.dart';
import 'processor.dart';
import 'protocol.dart';

/// The web worker processor: the script at [url], started on the first
/// session.
PitchWorkerProcessor newPitchWorkerProcessor({
  required String url,
  required bool fallback,
  required Duration startTimeout,
}) => _WebProcessor(url, fallback, startTimeout);

const _setupCommand = 'dart run tekartik_pitch_web_worker:setup';

class _WebProcessor implements PitchWorkerProcessor {
  _WebProcessor(this.url, this.fallback, this.startTimeout);

  final String url;
  final bool fallback;
  final Duration startTimeout;

  web.Worker? _worker;
  Future<bool>? _ready;
  Completer<bool>? _started;
  var _lastId = 0;
  final _sessions = <int, _WorkerSession>{};
  var _closed = false;
  var _offThread = false;

  @override
  bool get offThread => _offThread;

  @override
  Future<bool> get ready =>
      _closed ? Future.value(false) : (_ready ??= _start());

  Future<bool> _start() async {
    var started = _started = Completer<bool>();
    try {
      var worker = _worker = web.Worker(url.toJS);
      worker.onmessage = _onMessage.toJS;
      worker.onerror = _onError.toJS;
    } catch (e) {
      _warn('cannot start $url ($e)');
      return false;
    }
    var ok = await started.future.timeout(
      startTimeout,
      onTimeout: () {
        _warn('$url did not start within $startTimeout');
        return false;
      },
    );
    if (!ok) {
      _terminate();
    }
    return ok;
  }

  void _onMessage(web.MessageEvent event) {
    var message = event.data as PitchWorkerJsMessage?;
    switch (message?.type) {
      case pitchWorkerMessageReady:
        var version = message!.version;
        if (version == pitchWorkerProtocolVersion) {
          _started?.complete(true);
        } else {
          _warn(
            '$url speaks version $version, not $pitchWorkerProtocolVersion: '
            'build it again ($_setupCommand)',
          );
          _started?.complete(false);
        }
      case pitchWorkerMessageSteps:
        _sessions[message!.id]?._steps(message.steps!);
      case pitchWorkerMessageError:
        _sessions[message!.id]?._error(
          PitchWorkerException(message.error ?? 'error'),
        );
    }
  }

  void _onError(web.Event event) {
    var started = _started;
    if (started != null && !started.isCompleted) {
      _warn('cannot load $url ($_setupCommand builds it)');
      started.complete(false);
      return;
    }
    var error = PitchWorkerException(
      event.isA<web.ErrorEvent>()
          ? (event as web.ErrorEvent).message
          : 'worker error',
    );
    for (var session in _sessions.values.toList()) {
      session._error(error);
    }
    _terminate();
    _ready = null;
  }

  void _terminate() {
    _worker?.terminate();
    _worker = null;
  }

  void _warn(String message) {
    web.console.warn(
      'PitchWorkerProcessor: $message, analyzing on the main thread'.toJS,
    );
  }

  void _post(PitchWorkerJsMessage message, [JSArray<JSAny>? transfer]) {
    var worker = _worker;
    if (worker == null) {
      return;
    }
    if (transfer == null) {
      worker.postMessage(message);
    } else {
      worker.postMessage(message, transfer);
    }
  }

  @override
  Future<PitchSession> open(PitchRunner runner) async {
    if (_closed) {
      throw StateError('PitchWorkerProcessor closed');
    }
    if (!await ready || _worker == null) {
      if (!fallback) {
        throw StateError('$url not started ($_setupCommand builds it)');
      }
      _offThread = false;
      return PitchProcessor.local.open(runner);
    }
    _offThread = true;
    var id = ++_lastId;
    var session = _sessions[id] = _WorkerSession(this, id);
    _post(
      PitchWorkerJsMessage(
        type: pitchWorkerMessageOpen,
        id: id,
        runner: jsonEncode(runner.toJson()),
      ),
    );
    return session;
  }

  @override
  Future<void> close() async {
    _closed = true;
    var started = _started;
    if (started != null && !started.isCompleted) {
      started.complete(false);
    }
    _terminate();
    for (var session in _sessions.values.toList()) {
      unawaited(session.close());
    }
  }
}

class _WorkerSession implements PitchSession {
  _WorkerSession(this._processor, this._id);

  final _WebProcessor _processor;
  final int _id;
  final _controller = StreamController<PitchStep>();
  var _closed = false;

  @override
  Stream<PitchStep> get steps => _controller.stream;

  void _steps(String json) {
    if (_closed) {
      return;
    }
    for (var step in jsonDecode(json) as List) {
      _controller.add(
        PitchStep.fromJson((step as Map).cast<String, Object?>()),
      );
    }
  }

  void _error(Object error) {
    if (!_closed) {
      _controller.addError(error);
    }
  }

  @override
  void add(Float32List samples) {
    if (_closed) {
      return;
    }
    var js = jsTransferableSamples(samples);
    _processor._post(
      PitchWorkerJsMessage(type: pitchWorkerMessageChunk, id: _id, samples: js),
      [js.buffer].toJS,
    );
  }

  @override
  void setAnalyses(List<PitchAnalysis> analyses) {
    if (_closed) {
      return;
    }
    _processor._post(
      PitchWorkerJsMessage(
        type: pitchWorkerMessageAnalyses,
        id: _id,
        analyses: jsonEncode([
          for (var analysis in analyses) analysis.toJson(),
        ]),
      ),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _processor._sessions.remove(_id);
    _processor._post(
      PitchWorkerJsMessage(type: pitchWorkerMessageClose, id: _id),
    );
    unawaited(_controller.close());
  }
}
