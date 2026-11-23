/// Plays sounds on the VM and in a browser: [AudioPlay], [audioPlay] (the
/// player of this platform), [audioPlaySamples], [audioPlayWavBytes]. The
/// platform parts: `audio_play_io.dart` (the host's players: a target sink
/// and stream properties on PipeWire) and `audio_play_web.dart` (Web Audio).
library;

export 'src/audio_play.dart'
    show AudioPlay, AudioPlayException, audioSamplesToWavBytes;
export 'src/audio_play_default.dart'
    show audioPlay, audioPlaySamples, audioPlayWavBytes;
