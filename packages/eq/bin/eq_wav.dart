import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:tekartik_audio_eq/audio_eq.dart';
import 'package:tekartik_wav/wav_file.dart';
import 'package:tekartik_wav/wav_file_fs.dart';

String _builtinKey(EqPreset preset) =>
    preset.name.toLowerCase().replaceAll(' ', '_');

/// Applies an equalizer preset to a WAV file:
///
///     dart run tekartik_audio_eq:eq_wav in.wav out.wav --preset preset.json
///     dart run tekartik_audio_eq:eq_wav in.wav out.wav --builtin bass_boost
///
/// The preset is a JSON file (`--preset`, the `EqPreset.toJson` form) or a
/// built in one (`--builtin`); `--auto-preamp` replaces its preamp so that
/// the curve stays at or below 0 dB. Exit code 64 on a usage error, 65 on a
/// bad file.
Future<void> main(List<String> args) async {
  var builtins = {for (var p in EqPresets.all) _builtinKey(p): p};
  var parser = ArgParser()
    ..addOption('preset', abbr: 'p', help: 'Preset JSON file (EqPreset.toJson)')
    ..addOption('builtin', abbr: 'b', allowed: builtins.keys)
    ..addFlag('auto-preamp', help: 'Preamp from the curve (no clipping)')
    ..addFlag('help', abbr: 'h', negatable: false);
  ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 64;
    return;
  }
  if (results.flag('help') || results.rest.length != 2) {
    stdout.writeln(
      'eq_wav <in.wav> <out.wav> (--preset <file> | --builtin <name>)',
    );
    stdout.writeln(parser.usage);
    exitCode = results.flag('help') ? 0 : 64;
    return;
  }
  var presetPath = results.option('preset');
  var builtinName = results.option('builtin');
  EqPreset preset;
  if (presetPath != null) {
    try {
      var json = jsonDecode(await File(presetPath).readAsString());
      if (json is! Map<String, Object?>) {
        throw const FormatException('A preset must be an object');
      }
      preset = EqPreset.fromJson(json);
    } on FormatException catch (e) {
      stderr.writeln('$presetPath: ${e.message}');
      exitCode = 65;
      return;
    }
  } else if (builtinName != null) {
    preset = builtins[builtinName]!;
  } else {
    stderr.writeln('--preset or --builtin needed');
    exitCode = 64;
    return;
  }
  if (results.flag('auto-preamp')) {
    preset = preset.copyWith(preamp: eqAutoPreamp(preset));
  }
  var wav = WavFile();
  try {
    await wav.read(File(results.rest[0]).openRead());
  } on FormatException catch (e) {
    stderr.writeln('${results.rest[0]}: ${e.message}');
    exitCode = 65;
    return;
  }
  var buffers = wav.soundBuffers!;
  var sampleRate = wav.sampleRate!;
  var processor = EqProcessor(
    channels: buffers.length,
    sampleRate: sampleRate.toDouble(),
    preset: preset,
  );
  var frames = buffers[0].length;
  const block = 4096;
  for (var offset = 0; offset < frames; offset += block) {
    var count = frames - offset < block ? frames - offset : block;
    var views = [
      for (var buffer in buffers)
        Float32List.sublistView(buffer.data, offset, offset + count),
    ];
    processor.process(views, views);
  }
  var clipped = 0;
  for (var buffer in buffers) {
    for (var value in buffer.data) {
      if (value.abs() > 1) {
        clipped++;
      }
    }
  }
  await File(results.rest[1]).writeAsBytes(
    writeWavBytes(
      sampleRate: sampleRate,
      numChannels: buffers.length,
      soundBuffers: buffers,
    ),
  );
  stdout.writeln(
    '${results.rest[1]}: ${preset.bands.length} bands, preamp '
    '${eqFormatNumber(preset.preamp)} dB, $frames frames'
    '${clipped > 0 ? ', $clipped samples clipped' : ''}',
  );
}
