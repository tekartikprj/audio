/// The messages between the page and the pitch worker, pure Dart.
library;

/// The version of the messages: a worker script built for another version
/// (an older `web/pitch_worker.js`) is not used.
const pitchWorkerProtocolVersion = 1;

/// The default file name of the worker script, next to the page.
const pitchWorkerJsFilename = 'pitch_worker.js';

/// Message type, worker to page, once started (with its `version`).
const pitchWorkerMessageReady = 'ready';

/// Message type, page to worker: open the session `id` running the runner
/// of the JSON `runner`.
const pitchWorkerMessageOpen = 'open';

/// Message type, page to worker: the `samples` of the session `id`.
const pitchWorkerMessageChunk = 'chunk';

/// Message type, page to worker: the JSON `analyses` of the session `id`.
const pitchWorkerMessageAnalyses = 'analyses';

/// Message type, page to worker: close the session `id`.
const pitchWorkerMessageClose = 'close';

/// Message type, worker to page: the JSON `steps` of the session `id`.
const pitchWorkerMessageSteps = 'steps';

/// Message type, worker to page: the session `id` failed with `error`.
const pitchWorkerMessageError = 'error';

/// An error of the worker.
class PitchWorkerException implements Exception {
  /// What went wrong.
  final String message;

  /// An error, [message] telling what.
  PitchWorkerException(this.message);

  @override
  String toString() => 'PitchWorkerException: $message';
}
