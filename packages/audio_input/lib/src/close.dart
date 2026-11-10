import 'dart:async';
import 'dart:typed_data';

/// A stream controller remembering whether its listener cancelled.
class AudioInputController {
  /// The controller.
  late final StreamController<Float32List> controller =
      StreamController<Float32List>(
        onListen: _wakeUp,
        onResume: _wakeUp,
        onCancel: () {
          _cancelled = true;
          _wakeUp();
        },
      );

  var _cancelled = false;

  /// True once the listener cancelled.
  bool get cancelled => _cancelled;

  Completer<void>? _waiting;

  void _wakeUp() {
    var waiting = _waiting;
    _waiting = null;
    waiting?.complete();
  }

  /// Completes once a chunk added would be delivered: the stream is
  /// listened and not paused, or there is nobody to wait for any more
  /// (cancelled, closed).
  Future<void> ready() async {
    while (controller.isPaused && !_cancelled && !controller.isClosed) {
      await (_waiting ??= Completer<void>()).future;
    }
  }

  /// Ends the stream for its listener: waits for the done event when it
  /// listens, leaves it buffered when nobody listened yet (or paused).
  /// After a cancel there is no one to tell and nothing is done: closing
  /// then would wait forever (and, in a fake async test zone, stop the
  /// microtasks).
  Future<void> close() async {
    if (_cancelled) {
      return;
    }
    if (controller.hasListener && !controller.isPaused) {
      await controller.close();
    } else {
      unawaited(controller.close());
    }
    // A producer waiting in ready() stops.
    _wakeUp();
  }
}
