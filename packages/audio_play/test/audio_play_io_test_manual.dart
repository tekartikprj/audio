// Real players, run by hand: dart test test/audio_play_io_test_manual.dart
//
// Linux (PipeWire): a null sink is created, the sounds go there through
// pw-play and paplay with a target (nothing reaches the speakers), its
// monitor is recorded and must hold the tone; the sink is removed.
// macOS, Windows: a quiet tone of half a second on the speakers, then one
// stopped after half a second.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_audio_play/audio_play_io.dart';
import 'package:tekartik_wav/wav_file.dart';
import 'package:test/test.dart';

const _rate = 48000;
const _sink = 'tekartik_audio_play_test';

Float32List _tone(double seconds, {double amplitude = 0.1}) =>
    Float32List.fromList([
      for (var i = 0; i < seconds * _rate; i++)
        amplitude * sin(2 * pi * 440 * i / _rate),
    ]);

double _peak(Float32List data) =>
    data.fold(0.0, (peak, value) => max(peak, value.abs()));

void main() {
  var quiet = Shell(verbose: false);
  if (Platform.isLinux) {
    group('linux, to a null sink', () {
      late String module;
      late Directory dir;
      setUpAll(() async {
        dir = await Directory.systemTemp.createTemp('audio_play_io_manual');
        module = (await quiet.runExecutableArguments('pactl', [
          'load-module',
          'module-null-sink',
          'sink_name=$_sink',
          'sink_properties=device.description=$_sink',
        ])).outText.trim();
      });
      tearDownAll(() async {
        await quiet.runExecutableArguments('pactl', ['unload-module', module]);
        await dir.delete(recursive: true);
      });

      /// Plays a 1 s tone with [player] to the null sink while recording its
      /// monitor; returns the peak recorded.
      Future<double> playRecorded(AudioPlayIoPlayer player) async {
        var path = join(dir.path, '${player.name}.wav');
        var recorder = Shell(verbose: false, throwOnError: false);
        var recording = recorder.runExecutableArguments('parecord', [
          '--device=$_sink.monitor',
          '--file-format=wav',
          '--rate=$_rate',
          '--channels=1',
          path,
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        var stopwatch = Stopwatch()..start();
        await AudioPlayIo(
          player: player,
          options: const AudioPlayIoOptions(
            target: _sink,
            properties: {'application.name': 'tekartik-audio-play-test'},
          ),
        ).playSamples([_tone(1)], sampleRate: _rate);
        expect(
          stopwatch.elapsed,
          greaterThan(const Duration(milliseconds: 900)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
        recorder.kill(ProcessSignal.sigint);
        try {
          await recording;
        } on ShellException catch (_) {
          // Killed (the recording is done).
        }
        var wav = WavFile();
        await wav.read(File(path).openRead());
        return _peak(wav.soundBuffers!.first.data);
      }

      for (var player in [AudioPlayIoPlayer.pwPlay, AudioPlayIoPlayer.paplay]) {
        test(
          '${player.name} with a target',
          () async {
            // 0.1 asked, a little less once recorded (the rounding of 16 bits).
            expect(await playRecorded(player), closeTo(0.1, 0.01));
          },
          skip: whichSync(player.executable) == null
              ? '${player.executable} not found'
              : null,
        );
      }

      test('the default player of this host has a target', () {
        expect(audioPlayIoFindPlayer(target: true), isNotNull);
      });
    });
  } else {
    test('a quiet tone on the speakers', () async {
      var stopwatch = Stopwatch()..start();
      await audioPlaySamples([_tone(0.5)], sampleRate: _rate);
      expect(stopwatch.elapsed, greaterThan(const Duration(milliseconds: 400)));
    });
    test('stop', () async {
      var io = AudioPlayIo();
      var done = io.playSamples([_tone(5)], sampleRate: _rate);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      var stopwatch = Stopwatch()..start();
      await io.stop();
      await done;
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  }
}
