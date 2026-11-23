/// Plays sounds from a Dart VM program (no Flutter, no native code) through
/// the player its OS ships: `pw-play`, `paplay` or `aplay` on Linux (to a
/// chosen sink with stream properties on PipeWire), `afplay` on macOS,
/// PowerShell's SoundPlayer on Windows. Also exports `audio_play.dart`.
library;

export 'src/audio_play.dart'
    show AudioPlay, AudioPlayException, audioSamplesToWavBytes;
export 'src/audio_play_default.dart'
    show audioPlay, audioPlaySamples, audioPlayWavBytes;
export 'src/audio_play_io.dart'
    show
        AudioPlayIo,
        AudioPlayIoOptions,
        AudioPlayIoPlayer,
        audioPlayIoDefault,
        audioPlayIoFindPlayer,
        audioPlayIoPipeWireProperties,
        audioPlayIoPlayers,
        audioPlayWavFile;
