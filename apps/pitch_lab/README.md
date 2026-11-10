# pitch_lab

The microphone, test sounds or a WAV file analyzed by every
`tekartik_pitch` algorithm at once:

- **Note**: the note, a needle, its cents and frequency, how steady (a lock
  once settled);
- **Strings**: the strings of an instrument (guitar, bass, ukulele, violin...)
  and the notes found by harmonic peeling;
- **Reeds**: the reeds of an accordion note (musette, violin registers),
  their cents and how fast they beat;
- **Notes**: the notes played, their share of the sound;
- **Compare**: YIN, autocorrelation and the harmonic product spectrum side by
  side, the time and window of every analysis, the level of the sound.

## Run

From this folder (a package of the repository workspace):

```sh
dart run tool/dev_build_setup.dart            # web/pitch_worker.js (once)
flutter run -d chrome                         # the lab
flutter run -d chrome -t lib/main_demo.dart   # starts on a test sound
flutter run -d linux                          # desktop (microphone: parecord)
flutter test                                  # widget tests, no microphone
tkhostelio deploy-demo                        # site pitch_lab_demo (dev)
```

- Platforms: the web and Linux have their runner. Another platform needs
  `flutter create --platforms=<platform> .` and the microphone permission of
  `tekartik_audio_input_record` (`RECORD_AUDIO` on Android,
  `NSMicrophoneUsageDescription` on iOS/macOS).
- On the web the analyses run in a web worker built from Dart
  (`web/pitch_worker.js`, git-ignored, rebuilt by the setup step when the SDK
  or a package changed). Without it they run on the main thread (a console
  warning; the Compare view says so): the lab works, the UI is less smooth.
- Test sounds and WAV files (16 bit PCM, any sample rate, mixed to mono) loop
  in real time; no microphone needed.
