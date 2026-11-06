---
name: tekartik-pitch-web-worker
description: >-
  Use when running tekartik_pitch analyses off the main thread with
  tekartik_pitch_web_worker: PitchWorkerProcessor (a web worker on the web,
  an isolate on io, the main thread as a fallback), building
  pitch_worker.js with the setup step (dart run
  tekartik_pitch_web_worker:setup, tool/dev_build_setup.dart), and the
  PitchProcessor / PitchSession interface of tekartik_pitch.
---

# Pitch analyses in a worker (tekartik_pitch_web_worker)

## Guidelines

* Depend on it from git (`packages/pitch_web_worker` of
  `https://github.com/tekartikprj/audio`).
* The script: `web/pitch_worker.js`, built from Dart by
  `dart run tekartik_pitch_web_worker:setup` or `setupPitchWorker()` in the
  app's `tool/dev_build_setup.dart` (run_ci runs it before tests and
  builds; run it before a deploy that builds the web app). It is a build
  output: git-ignore it.
* `PitchWorkerProcessor({url: 'pitch_worker.js', fallback: true,
  startTimeout: 30 s})` implements `PitchProcessor` (tekartik_pitch):
  `open(runner)` gives a `PitchSession` (`add(chunk)`, `steps`,
  `setAnalyses`, `close`). A missing or outdated script (protocol version)
  falls back on the main thread (`offThread` false) unless
  `fallback: false` (then `open` throws a `StateError`). On io each session
  runs in its own isolate.
* With `tekartik_pitch_flutter`: `PitchListening(input, analyses: ...,
  processor: PitchWorkerProcessor())`; the steps arrive asynchronously
  (`onStep`, `step`), `a4` and `analyses` changes are sent to the worker.
* The chunks given to a worker session are transferred (detached) when
  they own their buffer: never reuse a chunk after `add`.
* The steps cross as JSON (`PitchStep.toJson`); `micros` measure the time
  inside the worker.
* Browser tests: build `test/pitch_worker.js` (setup with `dir: 'test'`)
  and use `PitchWorkerProcessor(fallback: false)`.
