@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:tekartik_audio_play/audio_play_io.dart';
import 'package:test/test.dart';

/// The fake player of `test/src/fake_player.dart`, run by this Dart.
final _fake = AudioPlayIoPlayer(
  name: 'fake',
  executable: Platform.resolvedExecutable,
  arguments: (path, options) => [join('test', 'src', 'fake_player.dart'), path],
);

void main() {
  test('players of each system', () {
    expect(audioPlayIoPlayers('linux').map((p) => p.name), [
      'pw-play',
      'paplay',
      'aplay',
    ]);
    expect(audioPlayIoPlayers('macos').single.name, 'afplay');
    expect(audioPlayIoPlayers('windows').single.name, 'PowerShell SoundPlayer');
  });

  test('find', () {
    var linux = audioPlayIoPlayers('linux');
    String? only(String executable, String found) =>
        executable == found ? '/usr/bin/$found' : null;
    expect(
      audioPlayIoFindPlayer(players: linux, which: (e) => only(e, 'aplay')),
      AudioPlayIoPlayer.aplay,
    );
    // aplay cannot play to a target.
    expect(
      audioPlayIoFindPlayer(
        players: linux,
        target: true,
        which: (e) => only(e, 'aplay'),
      ),
      isNull,
    );
    expect(
      audioPlayIoFindPlayer(
        players: linux,
        target: true,
        which: (e) => e == 'paplay' || e == 'aplay' ? e : null,
      ),
      AudioPlayIoPlayer.paplay,
    );
    expect(audioPlayIoFindPlayer(players: linux, which: (_) => null), isNull);
  });

  test('arguments', () {
    const options = AudioPlayIoOptions(
      target: 'my_sink',
      properties: {'application.name': 'My "app"', 'node.name': 'my-play'},
    );
    expect(AudioPlayIoPlayer.pwPlay.argumentsFor('/a.wav'), ['/a.wav']);
    expect(AudioPlayIoPlayer.pwPlay.argumentsFor('/a.wav', options), [
      '--target',
      'my_sink',
      '-P',
      r'{ application.name = "My \"app\"" node.name = "my-play" }',
      '/a.wav',
    ]);
    expect(AudioPlayIoPlayer.paplay.argumentsFor('/a.wav', options), [
      '--device=my_sink',
      '--property=application.name=My "app"',
      '--property=node.name=my-play',
      '/a.wav',
    ]);
    expect(AudioPlayIoPlayer.aplay.argumentsFor('/a.wav', options), [
      '-q',
      '/a.wav',
    ]);
    expect(
      AudioPlayIoPlayer.windowsSoundPlayer.argumentsFor(r"C:\Temp\it's.wav"),
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r"(New-Object System.Media.SoundPlayer 'C:\Temp\it''s.wav').PlaySync()",
      ],
    );
  });

  test('wav bytes', () {
    var bytes = audioSamplesToWavBytes([
      Float32List.fromList([0, 0.5, -0.5]),
      Float32List.fromList([0, 1, -1]),
    ], sampleRate: 22050);
    var data = ByteData.sublistView(bytes);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(data.getUint16(22, Endian.little), 2); // channels
    expect(data.getUint32(24, Endian.little), 22050);
    expect(data.getUint16(34, Endian.little), 16); // bits
    expect(bytes.length, 44 + 3 * 2 * 2);
    expect(
      () => audioSamplesToWavBytes([], sampleRate: 22050),
      throwsArgumentError,
    );
  });

  group('play', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('audio_play_io_test');
    });
    tearDown(() => dir.delete(recursive: true));

    AudioPlayIo playIo(String mode, {AudioPlayIoOptions? options}) =>
        AudioPlayIo(
          player: _fake,
          options: options ?? const AudioPlayIoOptions(),
          environment: {
            'FAKE_PLAYER_MODE': mode,
            'FAKE_PLAYER_OUT': join(dir.path, 'out.wav'),
          },
        );

    test('samples reach the player, the temporary file is deleted', () async {
      var samples = [Float32List.fromList(List.filled(480, 0.25))];
      await playIo('copy').playSamples(samples, sampleRate: 48000);
      expect(
        await File(join(dir.path, 'out.wav')).readAsBytes(),
        audioSamplesToWavBytes(samples, sampleRate: 48000),
      );
      var left = Directory.systemTemp.listSync().where(
        (e) => basename(e.path).startsWith('tekartik_audio_play'),
      );
      expect(left, isEmpty);
    });

    test('stop', () async {
      var io = playIo('wait');
      var stopwatch = Stopwatch()..start();
      var done = io.playWavBytes(
        audioSamplesToWavBytes([Float32List(48)], sampleRate: 48000),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      await io.stop();
      await done; // no error
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 20)));
    });

    test('errors', () async {
      var path = join(dir.path, 'in.wav');
      await File(path).writeAsBytes(
        audioSamplesToWavBytes([Float32List(48)], sampleRate: 48000),
      );
      await expectLater(
        playIo('fail').playWavFile(path),
        throwsA(
          isA<AudioPlayException>().having(
            (e) => e.message,
            'message',
            allOf(contains('exit code 3'), contains('no device')),
          ),
        ),
      );
      // A target the player cannot honor: refused, nothing played.
      await expectLater(
        playIo(
          'copy',
          options: const AudioPlayIoOptions(target: 'my_sink'),
        ).playWavFile(path),
        throwsA(isA<AudioPlayException>()),
      );
      expect(File(join(dir.path, 'out.wav')).existsSync(), isFalse);
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
