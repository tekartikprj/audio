import 'dart:async';
import 'dart:typed_data';

/// A stream controller remembering whether its listener cancelled.
class AudioInputController {
  /// The controller.
  late final StreamController<Float32List> controller =
      StreamController<Float32List>(onCancel: () => _cancelled = true);

  var _cancelled = false;

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
  }
}
