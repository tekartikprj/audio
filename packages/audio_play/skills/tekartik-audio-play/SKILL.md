---
name: tekartik-audio-play
description: >-
  Use when playing a sound from dart with tekartik_audio_play: float
  samples or WAV bytes played from a command line script, a server or a
  desktop app without Flutter (pw-play, paplay, aplay, afplay, PowerShell),
  to a chosen PipeWire / PulseAudio sink with stream properties (a test
  tone into a null sink), or in a browser through Web Audio.
---

# Playing sounds (tekartik_audio_play)

## Guidelines

* Depend on it from git:

  ```yaml
  dependencies:
    tekartik_audio_play:
      git:
        url: https://github.com/tekartikprj/audio
        path: packages/audio_play
  ```

* Any platform: `package:tekartik_audio_play/audio_play.dart`,
  `await audioPlaySamples([channel0, ...], sampleRate: 48000)` (samples
  from -1 to 1) or `audioPlayWavBytes(bytes)`; each play completes at the
  end of its sound; `audioPlay.stop()` ends them (no error).
  `audioSamplesToWavBytes` writes 16 bit PCM.
* VM: `package:tekartik_audio_play/audio_play_io.dart`. `AudioPlayIo()`
  finds the host's player (`audioPlayIoFindPlayer`; `player` is null when
  none, a play then throws `AudioPlayException`). `AudioPlayIo(options:
  AudioPlayIoOptions(target: sinkName, properties: {'application.name':
  'x', 'node.name': 'y'}))` plays to that sink with `pw-play --target -P` or
  `paplay --device --property`; a player without a target is refused, never
  falls back to the speakers. `environment:` is added to the player's.
  `playWavFile(path)` plays a file as is.
* Web: `package:tekartik_audio_play/audio_play_web.dart`, `AudioPlayWeb`.
  The first play must follow a user gesture (the AudioContext starts
  suspended and the play waits); headless Chrome takes
  `--autoplay-policy=no-user-gesture-required`, plus `--mute-audio` in tests.
* Chrome on Linux plays through PulseAudio: `PULSE_SINK=<sink>` in its
  environment routes it (a null sink in a check).
* macOS and Windows players are not checked on a real host yet.
