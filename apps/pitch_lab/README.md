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

```sh
flutter run -d chrome                         # the lab
flutter run -d chrome -t lib/main_demo.dart   # starts on a test sound
tkhostelio deploy-demo                        # site pitch_lab_demo (dev)
```
