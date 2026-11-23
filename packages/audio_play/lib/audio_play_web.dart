/// Plays sounds in a browser through Web Audio ([AudioPlayWeb]). Also
/// exports `audio_play.dart`.
library;

export 'src/audio_play.dart'
    show AudioPlay, AudioPlayException, audioSamplesToWavBytes;
export 'src/audio_play_default.dart'
    show audioPlay, audioPlaySamples, audioPlayWavBytes;
export 'src/audio_play_web.dart' show AudioPlayWeb, audioPlayWebDefault;
