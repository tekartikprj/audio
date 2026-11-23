import '../audio_play.dart';

/// No player here (neither the VM nor a browser).
AudioPlay get audioPlayPlatform =>
    throw UnsupportedError('No audio player on this platform');
