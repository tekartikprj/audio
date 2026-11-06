# audio

Audio utilities

## Features

### tekartik_wav

- Wav file reader/writer.

### tekartik_pitch

- Pitch analysis: one note, several notes, tuning against targets, reeds of
  a note, which notes are played; several algorithms at once.

### tekartik_audio_input

- Audio input abstraction: mono chunks from a microphone, samples or a WAV
  file; the level of the sound.

### Flutter

- tekartik_audio_input_flutter: level widgets (bar, pulsing microphone),
  no plugin.
- tekartik_audio_input_record: the microphone (record plugin).
- tekartik_pitch_flutter: listening controller, gauge, reeds, strings.

### tekartik_pitch_web_worker

- The analyses in a web worker (an isolate on io).

### apps/pitch_lab

- Every algorithm at once on the microphone, test sounds or a WAV file.

Plan: [doc/pitch_plan.md](doc/pitch_plan.md).

