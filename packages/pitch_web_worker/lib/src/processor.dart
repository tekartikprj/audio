import 'package:tekartik_pitch/pitch.dart';

import 'processor_io.dart'
    if (dart.library.js_interop) 'processor_web.dart'
    as platform;
import 'protocol.dart';

/// Runs the analyses off the main thread: in a web worker on the web (the
/// script built by the setup step, `pitch_worker.js` next to the page), in
/// an isolate per session on io.
abstract class PitchWorkerProcessor implements PitchProcessor {
  /// A processor loading [url] (relative to the page) when it first opens a
  /// session.
  ///
  /// When the script cannot start (missing, not answering within
  /// [startTimeout], built for another protocol version), the sessions run
  /// on the main thread ([PitchProcessor.local]), unless [fallback] is
  /// false: [open] throws a [StateError] then. [url], [fallback] and
  /// [startTimeout] are ignored on io.
  factory PitchWorkerProcessor({
    String url = pitchWorkerJsFilename,
    bool fallback = true,
    Duration startTimeout = const Duration(seconds: 30),
  }) => platform.newPitchWorkerProcessor(
    url: url,
    fallback: fallback,
    startTimeout: startTimeout,
  );

  /// True when the sessions run off the main thread, false on the
  /// fallback. Starts the worker.
  Future<bool> get ready;

  /// Stops the worker: the sessions end.
  Future<void> close();
}
