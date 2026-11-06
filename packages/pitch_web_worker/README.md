# tekartik_pitch_web_worker

`tekartik_pitch` analyses off the main thread: `PitchWorkerProcessor` runs
the sessions of a `PitchRunner` in a web worker on the web
(`pitch_worker.js`, compiled from Dart by the setup step), in an isolate per
session on io, on the main thread as a fallback when the script is missing.

## Setup

```yaml
dependencies:
  tekartik_pitch_web_worker:
    git:
      url: https://github.com/tekartikprj/audio
      path: packages/pitch_web_worker
```

Build the script next to the page (again only when the SDK or a package
changed), from the app folder:

```sh
dart run tekartik_pitch_web_worker:setup   # web/pitch_worker.js
```

or in `tool/dev_build_setup.dart`, which `run_ci` runs before the tests and
the build:

```dart
import 'package:tekartik_pitch_web_worker/setup.dart';

Future<void> main() => setupPitchWorker();
```

## Usage

```dart
var listening = PitchListening(
  microphone,
  analyses: analyses,
  processor: PitchWorkerProcessor(),
);
```

Or directly: `var session = await processor.open(runner);`,
`session.add(chunk)`, `session.steps.listen(...)`,
`session.setAnalyses(...)`, `session.close()`. The chunks are moved to the
worker (their buffer is transferred when they own it): do not reuse them.
