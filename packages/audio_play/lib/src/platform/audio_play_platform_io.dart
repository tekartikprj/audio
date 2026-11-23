import '../audio_play.dart';
import '../audio_play_io.dart';

/// The VM: a player of the host.
AudioPlay get audioPlayPlatform => audioPlayIoDefault;
