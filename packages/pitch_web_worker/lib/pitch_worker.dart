/// tekartik_pitch analyses off the main thread: a [PitchWorkerProcessor]
/// runs the sessions of a `PitchRunner` in a web worker on the web
/// (`pitch_worker.js`, built by the setup step), in an isolate on io.
///
/// ```dart
/// var listening = PitchListening(input, analyses: analyses,
///     processor: PitchWorkerProcessor());
/// ```
library;

export 'src/processor.dart' show PitchWorkerProcessor;
export 'src/protocol.dart'
    show
        pitchWorkerJsFilename,
        pitchWorkerProtocolVersion,
        PitchWorkerException;
