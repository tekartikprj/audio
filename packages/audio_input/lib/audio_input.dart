/// Audio input in pure Dart: [AudioInput] gives mono `Float32List` chunks
/// from a microphone (see the Flutter package), samples or a WAV file
/// ([AudioInputSamples]) or by hand ([AudioInputPush]).
library;

export 'src/audio_input.dart';
export 'src/push.dart';
export 'src/samples.dart';
