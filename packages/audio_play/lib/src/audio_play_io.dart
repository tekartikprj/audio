import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'audio_play.dart';

/// Where a sound goes and how its stream is labelled.
class AudioPlayIoOptions {
  /// The sink to play to, null for the default one: on PipeWire a node
  /// name or serial (`pw-play --target`), on PulseAudio a sink name
  /// (`paplay --device`). Only the players with
  /// [AudioPlayIoPlayer.supportsTarget] take one.
  final String? target;

  /// Properties of the stream (PipeWire node or PulseAudio stream
  /// properties: `application.name`, `node.name`, `media.name`,
  /// `media.role`...), so the sound can be told from others in the graph;
  /// the players without properties leave them out.
  final Map<String, String> properties;

  /// Options of a sound played to [target] with [properties].
  const AudioPlayIoOptions({this.target, this.properties = const {}});
}

/// A command line program that plays a WAV file and exits when it ends.
class AudioPlayIoPlayer {
  /// Its name, as shown (`pw-play`, `PowerShell SoundPlayer`).
  final String name;

  /// The executable, looked for on the `PATH` (`pw-play`, `afplay`,
  /// `powershell`).
  final String executable;

  /// Whether it plays to a chosen sink ([AudioPlayIoOptions.target]).
  final bool supportsTarget;

  final List<String> Function(String path, AudioPlayIoOptions options)
  _arguments;

  /// A player running [executable] with the arguments `arguments` returns
  /// for the path of a WAV file and the options of the sound; [name]
  /// defaults to [executable].
  AudioPlayIoPlayer({
    required this.executable,
    required this._arguments,
    this.supportsTarget = false,
    String? name,
  }) : name = name ?? executable;

  /// The arguments that play the WAV file at [path] with [options] (the
  /// default sink when none).
  List<String> argumentsFor(
    String path, [
    AudioPlayIoOptions options = const AudioPlayIoOptions(),
  ]) => _arguments(path, options);

  /// PipeWire's player (Linux): `--target`, `-P` for the properties.
  static final pwPlay = AudioPlayIoPlayer(
    executable: 'pw-play',
    supportsTarget: true,
    arguments: (path, options) => [
      if (options.target != null) ...['--target', options.target!],
      if (options.properties.isNotEmpty) ...[
        '-P',
        audioPlayIoPipeWireProperties(options.properties),
      ],
      path,
    ],
  );

  /// PulseAudio's player, also served by PipeWire (Linux): `--device`,
  /// `--property`.
  static final paplay = AudioPlayIoPlayer(
    executable: 'paplay',
    supportsTarget: true,
    arguments: (path, options) => [
      if (options.target != null) '--device=${options.target}',
      for (var property in options.properties.entries)
        '--property=${property.key}=${property.value}',
      path,
    ],
  );

  /// ALSA's player (Linux), quiet; the default device only.
  static final aplay = AudioPlayIoPlayer(
    executable: 'aplay',
    arguments: (path, options) => ['-q', path],
  );

  /// The player of macOS; the default device only.
  static final afplay = AudioPlayIoPlayer(
    executable: 'afplay',
    arguments: (path, options) => [path],
  );

  /// Windows: `System.Media.SoundPlayer` through PowerShell (PCM WAV only,
  /// which is what this package writes); the default device only.
  static final windowsSoundPlayer = AudioPlayIoPlayer(
    name: 'PowerShell SoundPlayer',
    executable: 'powershell',
    arguments: (path, options) {
      var quoted = "'${path.replaceAll("'", "''")}'";
      return [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '(New-Object System.Media.SoundPlayer $quoted).PlaySync()',
      ];
    },
  );

  @override
  String toString() => name;
}

/// [properties] as the value of `pw-play -P`: `{ key = "value" ... }`.
String audioPlayIoPipeWireProperties(Map<String, String> properties) {
  String quoted(String value) =>
      '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  return '{ ${[for (var p in properties.entries) '${p.key} = ${quoted(p.value)}'].join(' ')} }';
}

/// The players tried on [operatingSystem] (a `Platform.operatingSystem`
/// value, this host's by default), in order: `pw-play`, `paplay`, `aplay`
/// on Linux (and any other system), `afplay` on macOS, the PowerShell
/// SoundPlayer on Windows.
List<AudioPlayIoPlayer> audioPlayIoPlayers([String? operatingSystem]) {
  switch (operatingSystem ?? Platform.operatingSystem) {
    case 'macos':
      return [AudioPlayIoPlayer.afplay];
    case 'windows':
      return [AudioPlayIoPlayer.windowsSoundPlayer];
    default:
      return [
        AudioPlayIoPlayer.pwPlay,
        AudioPlayIoPlayer.paplay,
        AudioPlayIoPlayer.aplay,
      ];
  }
}

/// The first of [players] (by default [audioPlayIoPlayers] of this host)
/// whose executable is found, by [which] (by default process_run's
/// `whichSync` on the `PATH` of [environment] added to this process's),
/// among those with [AudioPlayIoPlayer.supportsTarget] when [target] is
/// true; null when none is.
AudioPlayIoPlayer? audioPlayIoFindPlayer({
  List<AudioPlayIoPlayer>? players,
  bool target = false,
  Map<String, String>? environment,
  String? Function(String executable)? which,
}) {
  which ??= (executable) => whichSync(executable, environment: environment);
  for (var player in players ?? audioPlayIoPlayers()) {
    if ((!target || player.supportsTarget) &&
        which(player.executable) != null) {
      return player;
    }
  }
  return null;
}

class _Playing {
  final Shell shell;
  var stopped = false;

  _Playing(this.shell);
}

/// Plays sounds through a player of this host ([player]) with [options];
/// each play completes when its sound ends, or when [stop] is called.
/// Several sounds may play at once (one player process each).
class AudioPlayIo implements AudioPlay {
  /// Where the sounds go and how their streams are labelled.
  final AudioPlayIoOptions options;

  /// Added to this process's environment for the player, and used to find
  /// it.
  final Map<String, String>? environment;

  AudioPlayIoPlayer? _player;
  final _playing = <_Playing>{};

  /// Plays with [player], by default the first one found on this host
  /// ([audioPlayIoFindPlayer]; one with a target when [options] has one),
  /// with [options] (the default sink when none).
  AudioPlayIo({
    this._player,
    this.options = const AudioPlayIoOptions(),
    this.environment,
  });

  /// The player used, null when none is found (a play then throws an
  /// [AudioPlayException]).
  AudioPlayIoPlayer? get player => _player ??= audioPlayIoFindPlayer(
    target: options.target != null,
    environment: environment,
  );

  /// Plays the WAV file at [path]; completes when it ends or is stopped.
  /// Throws an [AudioPlayException] when no player is found, when the
  /// player cannot play to [AudioPlayIoOptions.target] (rather than play
  /// to the default sink), or when it fails.
  Future<void> playWavFile(String path) async {
    var player = this.player;
    if (player == null) {
      throw AudioPlayException(
        'No audio player found${options.target != null ? ' with a target' : ''} '
        '(tried ${audioPlayIoPlayers().join(', ')})',
      );
    }
    if (options.target != null && !player.supportsTarget) {
      throw AudioPlayException('${player.name} cannot play to a target');
    }
    var playing = _Playing(
      Shell(throwOnError: false, verbose: false, environment: environment),
    );
    _playing.add(playing);
    try {
      var result = await playing.shell.runExecutableArguments(
        player.executable,
        player.argumentsFor(path, options),
      );
      if (result.exitCode != 0 && !playing.stopped) {
        throw AudioPlayException(
          '${player.name} failed (exit code ${result.exitCode}) '
                  '${result.stderr}'
              .trim(),
        );
      }
    } on ShellException catch (e) {
      if (!playing.stopped) {
        throw AudioPlayException('${player.name}: ${e.message}');
      }
    } finally {
      _playing.remove(playing);
    }
  }

  /// Plays [bytes], a whole WAV file, from a temporary file deleted at the
  /// end.
  @override
  Future<void> playWavBytes(Uint8List bytes) async {
    var dir = await Directory.systemTemp.createTemp('tekartik_audio_play');
    try {
      var path = join(dir.path, 'sound.wav');
      await File(path).writeAsBytes(bytes);
      await playWavFile(path);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  /// Plays [channels] (one list of samples from -1 to 1 per channel, all
  /// of the same length) at [sampleRate] Hz, as 16 bit PCM.
  @override
  Future<void> playSamples(
    List<Float32List> channels, {
    required int sampleRate,
  }) => playWavBytes(audioSamplesToWavBytes(channels, sampleRate: sampleRate));

  /// Stops every sound playing; their plays complete without error.
  @override
  Future<void> stop() async {
    for (var playing in [..._playing]) {
      playing.stopped = true;
      playing.shell.kill();
    }
  }
}

/// The [AudioPlayIo] of `audioPlay` on the VM: the first player found, to
/// the default sink.
final audioPlayIoDefault = AudioPlayIo();

/// Plays the WAV file at [path] with [audioPlayIoDefault] (see
/// [AudioPlayIo.playWavFile]).
Future<void> audioPlayWavFile(String path) =>
    audioPlayIoDefault.playWavFile(path);
