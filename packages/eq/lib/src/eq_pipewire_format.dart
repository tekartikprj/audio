import 'dart:convert';

import 'eq_band.dart';
import 'eq_biquad.dart';
import 'eq_number.dart';

/// The PipeWire builtin filter label of each type (`bq_*` biquads).
const eqPipeWireLabels = {
  EqFilterType.peaking: 'bq_peaking',
  EqFilterType.lowShelf: 'bq_lowshelf',
  EqFilterType.highShelf: 'bq_highshelf',
  EqFilterType.lowPass: 'bq_lowpass',
  EqFilterType.highPass: 'bq_highpass',
  EqFilterType.notch: 'bq_notch',
  EqFilterType.bandPass: 'bq_bandpass',
  EqFilterType.allPass: 'bq_allpass',
};

/// The name of the filter graph node of band [index] (from 0, counting
/// the enabled bands only) in [formatEqPipeWireFilterChainArgs]: its
/// controls are set live through `pw-cli set-param` (see
/// [formatEqPipeWireParams]), e.g. `"eq_band_1:Gain" 3.0`. [path] 1 is the
/// second equalizer of a crossfade chain (`eq_b_band_1`).
String eqPipeWireBandNodeName(int index, {int path = 0}) =>
    '${path == 0 ? 'eq' : 'eq_b'}_band_${index + 1}';

/// The name of the preamp node (a builtin `linear`, control `Mult`).
const eqPipeWirePreampNodeName = 'eq_preamp';

/// The name of the preamp node of [path] (0: [eqPipeWirePreampNodeName],
/// 1: the second equalizer of a crossfade chain).
String eqPipeWirePathPreampNodeName(int path) =>
    path == 0 ? eqPipeWirePreampNodeName : 'eq_b_preamp';

/// The name of the input node of a crossfade chain (a builtin `copy`
/// feeding both equalizers and the dry path).
const eqPipeWireInputNodeName = 'eq_input';

/// The name of the mixer summing the three paths of a crossfade chain.
const eqPipeWireMixNodeName = 'eq_mix';

/// The names of the gain nodes of a crossfade chain: the gains of the
/// first equalizer, of the second one and of the dry sound. Each is a
/// constant (a `sine` of frequency 0, the gain is its `Offset`) through a
/// low pass ([eqPipeWireGainSmoothing], `<name>_smooth`), multiplying its
/// path (`<name>_mult`): a new gain is reached smoothly, per sample.
///
/// Not PipeWire's `ramp` builtin: in PipeWire 1.6.2 its controls have no
/// range, and the filter graph clamps every control to its range, so its
/// `Start` and `Stop` are always 0 (it outputs silence).
const eqPipeWireGainNodeNames = ['eq_gain_a', 'eq_gain_b', 'eq_gain_dry'];

/// The cut-off (Hz) of the low pass smoothing a crossfade gain (Q 0.5,
/// critically damped: no overshoot); a new gain is reached in about 25 ms.
const eqPipeWireGainSmoothing = 40.0;

/// The band of an unused slot: a peaking band at 0 dB, which leaves the
/// sound unchanged.
const eqPipeWireIdentityBand = EqBand.peaking(1000, 0);

/// The gains of the three paths of a crossfade chain (each 0 to 1): the
/// first equalizer [a], the second one [b], the dry sound [dry].
class EqPipeWireMix {
  /// The gain of the first equalizer.
  final double a;

  /// The gain of the second equalizer.
  final double b;

  /// The gain of the sound without equalizer (bypass).
  final double dry;

  /// A mix of [a], [b] and [dry].
  const EqPipeWireMix({this.a = 0, this.b = 0, this.dry = 0});

  /// Only the first equalizer.
  static const pathA = EqPipeWireMix(a: 1);

  /// Only the second equalizer.
  static const pathB = EqPipeWireMix(b: 1);

  /// Only the dry sound.
  static const bypass = EqPipeWireMix(dry: 1);

  /// Only the equalizer [path] (0 or 1).
  static EqPipeWireMix path(int path) => path == 0 ? pathA : pathB;

  /// The gains in the order of [eqPipeWireGainNodeNames].
  List<double> get gains => [a, b, dry];

  @override
  bool operator ==(Object other) =>
      other is EqPipeWireMix &&
      other.a == a &&
      other.b == b &&
      other.dry == dry;

  @override
  int get hashCode => Object.hash(a, b, dry);

  @override
  String toString() => 'EqPipeWireMix(a: $a, b: $b, dry: $dry)';
}

/// The bands of the chain of [preset]: its enabled bands, then
/// [eqPipeWireIdentityBand] up to [slots] bands (no padding when the preset
/// has as many enabled bands or more).
List<EqBand> eqPipeWireSlotBands(EqPreset preset, {int slots = 0}) {
  var bands = preset.enabledBands.toList();
  return [
    ...bands,
    for (var i = bands.length; i < slots; i++) eqPipeWireIdentityBand,
  ];
}

/// Whether the chains of [a] and [b] (with [slots], see
/// [eqPipeWireSlotBands]) have the same nodes, a node type per slot: a
/// change from one to the other is then a live change of controls
/// ([formatEqPipeWireParams]); otherwise it needs a new chain.
bool eqPipeWireSameChain(EqPreset a, EqPreset b, {int slots = 0}) {
  var aBands = eqPipeWireSlotBands(a, slots: slots);
  var bBands = eqPipeWireSlotBands(b, slots: slots);
  if (aBands.length != bBands.length) {
    return false;
  }
  for (var i = 0; i < aBands.length; i++) {
    if (aBands[i].type != bBands[i].type) {
      return false;
    }
  }
  return true;
}

String _string(String value) => jsonEncode(value);

String _positions(int channels) => switch (channels) {
  1 => 'MONO',
  2 => 'FL FR',
  _ => [for (var c = 0; c < channels; c++) 'AUX$c'].join(' '),
};

String _bandControls(EqBand band) =>
    '"Freq" = ${eqFormatNumber(band.frequency)} '
    '"Q" = ${eqFormatNumber(band.q)} '
    '"Gain" = ${eqFormatNumber(band.type.hasGain ? band.gain : 0)}';

/// Writes the nodes of one equalizer path and returns its last node.
String _writePath(
  StringBuffer nodes,
  StringBuffer links,
  EqPreset preset,
  List<EqBand> bands,
  int path,
) {
  var preamp = eqPipeWirePathPreampNodeName(path);
  nodes.writeln(
    '            { type = builtin name = $preamp label = linear '
    'control = { "Mult" = ${eqFormatNumber(eqDbToLinear(preset.preamp))} "Add" = 0 } }',
  );
  var previous = preamp;
  for (var i = 0; i < bands.length; i++) {
    var node = eqPipeWireBandNodeName(i, path: path);
    nodes.writeln(
      '            { type = builtin name = $node '
      'label = ${eqPipeWireLabels[bands[i].type]} control = { '
      '${_bandControls(bands[i])} } }',
    );
    links.writeln(
      '            { output = "$previous:Out" input = "$node:In" }',
    );
    previous = node;
  }
  return previous;
}

/// The `args` of a `libpipewire-module-filter-chain` applying [preset]: a
/// sink named [nodeName] (`media.class = Audio/Sink`) whose sound goes
/// through a `linear` preamp node and one builtin `bq_*` node per enabled
/// band, then to [targetObject] (a sink name; the default sink when null)
/// as the passive stream `<nodeName>.output`. [description] is the name
/// shown in the sound settings ([nodeName] when null).
///
/// [slots] pads the chain with bands that change nothing
/// ([eqPipeWireSlotBands]): a band added later then changes controls only.
///
/// With [crossfade], the chain has two equalizers in parallel (the second
/// one, [eqPipeWireBandNodeName] with `path: 1`, starts as [preset] too)
/// and the dry sound, each multiplied by a smoothed gain
/// ([eqPipeWireGainNodeNames]) and summed: a live change that does not click
/// is the new controls on the equalizer not heard ([formatEqPipeWireParams]
/// with its `path`), then a crossfade to it ([formatEqPipeWireMixParams]);
/// a bypass is a crossfade to the dry sound. PipeWire applies controls once
/// per block, without smoothing: a change of a band heard steps, the gains
/// of a crossfade move per sample. [mix] is the starting mix.
///
/// The text is SPA JSON (the PipeWire conf syntax). Load it with
/// `pw-cli load-module libpipewire-module-filter-chain` followed by the
/// text, or put it in a conf ([formatEqPipeWireFilterChainConf]).
String formatEqPipeWireFilterChainArgs(
  EqPreset preset, {
  required String nodeName,
  String? description,
  int channels = 2,
  String? targetObject,
  int slots = 0,
  bool crossfade = false,
  EqPipeWireMix mix = EqPipeWireMix.pathA,
}) {
  var bands = eqPipeWireSlotBands(preset, slots: slots);
  var buffer = StringBuffer();
  var nodes = StringBuffer();
  var links = StringBuffer();
  var name = _string(description ?? nodeName);
  buffer.writeln('{');
  buffer.writeln('    node.description = $name');
  buffer.writeln('    media.name = $name');
  buffer.writeln('    filter.graph = {');
  if (crossfade) {
    nodes.writeln(
      '            { type = builtin name = $eqPipeWireInputNodeName label = copy }',
    );
    var gains = mix.gains;
    var lasts = <String>[];
    for (var path = 0; path < 2; path++) {
      links.writeln(
        '            { output = "$eqPipeWireInputNodeName:Out" '
        'input = "${eqPipeWirePathPreampNodeName(path)}:In" }',
      );
      lasts.add(_writePath(nodes, links, preset, bands, path));
    }
    lasts.add(eqPipeWireInputNodeName);
    for (var i = 0; i < 3; i++) {
      var gain = eqPipeWireGainNodeNames[i];
      var smooth = '${gain}_smooth';
      var mult = '${gain}_mult';
      nodes
        ..writeln(
          '            { type = builtin name = $gain label = sine control = '
          '{ "Freq" = 0 "Ampl" = 0 "Offset" = ${eqFormatNumber(gains[i])} } }',
        )
        ..writeln(
          '            { type = builtin name = $smooth label = bq_lowpass '
          'control = { "Freq" = ${eqFormatNumber(eqPipeWireGainSmoothing)} '
          '"Q" = 0.5 } }',
        )
        ..writeln('            { type = builtin name = $mult label = mult }');
      links
        ..writeln('            { output = "$gain:Out" input = "$smooth:In" }')
        ..writeln(
          '            { output = "${lasts[i]}:Out" input = "$mult:In 1" }',
        )
        ..writeln('            { output = "$smooth:Out" input = "$mult:In 2" }')
        ..writeln(
          '            { output = "$mult:Out" '
          'input = "$eqPipeWireMixNodeName:In ${i + 1}" }',
        );
    }
    nodes.writeln(
      '            { type = builtin name = $eqPipeWireMixNodeName label = mixer '
      'control = { "Gain 1" = 1 "Gain 2" = 1 "Gain 3" = 1 } }',
    );
  } else {
    _writePath(nodes, links, preset, bands, 0);
  }
  buffer.writeln('        nodes = [');
  buffer.write(nodes);
  buffer.writeln('        ]');
  buffer.writeln('        links = [');
  buffer.write(links);
  buffer.writeln('        ]');
  if (crossfade) {
    buffer.writeln('        inputs = [ "$eqPipeWireInputNodeName:In" ]');
    buffer.writeln('        outputs = [ "$eqPipeWireMixNodeName:Out" ]');
  }
  buffer.writeln('    }');
  buffer.writeln('    audio.channels = $channels');
  buffer.writeln('    audio.position = [ ${_positions(channels)} ]');
  buffer.writeln('    capture.props = {');
  buffer.writeln('        node.name = ${_string(nodeName)}');
  buffer.writeln('        media.class = Audio/Sink');
  buffer.writeln('    }');
  buffer.writeln('    playback.props = {');
  buffer.writeln('        node.name = ${_string('$nodeName.output')}');
  buffer.writeln('        node.passive = true');
  if (targetObject != null) {
    buffer.writeln('        target.object = ${_string(targetObject)}');
  }
  buffer.writeln('    }');
  buffer.write('}');
  return buffer.toString();
}

/// A whole PipeWire configuration running the filter chain of
/// [formatEqPipeWireFilterChainArgs] (same parameters) in its own process:
/// `pipewire -c <file>`. The chain lives as long as that process: when it
/// stops, the sink goes away and its streams fall back to another sink.
String formatEqPipeWireFilterChainConf(
  EqPreset preset, {
  required String nodeName,
  String? description,
  int channels = 2,
  String? targetObject,
  int slots = 0,
  bool crossfade = false,
  EqPipeWireMix mix = EqPipeWireMix.pathA,
}) {
  var args = formatEqPipeWireFilterChainArgs(
    preset,
    nodeName: nodeName,
    description: description,
    channels: channels,
    targetObject: targetObject,
    slots: slots,
    crossfade: crossfade,
    mix: mix,
  ).replaceAll('\n', '\n        ');
  return '''
# Generated by tekartik_audio_eq: ${preset.name}
context.properties = {
    log.level = 0
}
context.spa-libs = {
    audio.convert.* = audioconvert/libspa-audioconvert
    support.*       = support/libspa-support
}
context.modules = [
    { name = libpipewire-module-rt
        args = { }
        flags = [ ifexists nofail ]
    }
    { name = libpipewire-module-protocol-native }
    { name = libpipewire-module-client-node }
    { name = libpipewire-module-adapter }
    { name = libpipewire-module-filter-chain
        args = $args
    }
]
''';
}

/// The live controls of [preset] for the chain of
/// [formatEqPipeWireFilterChainArgs] (built with the same [slots]): the
/// `Props` value of a `pw-cli set-param` on the filter node (`{ params = [
/// "eq_band_1:Gain" 3 ... ] }`), for its equalizer [path] (1: the second
/// one of a crossfade chain). Only valid while the chain keeps its nodes
/// ([eqPipeWireSameChain]: a node's label cannot change live, write a new
/// chain otherwise).
String formatEqPipeWireParams(EqPreset preset, {int slots = 0, int path = 0}) {
  var bands = eqPipeWireSlotBands(preset, slots: slots);
  var preamp = eqPipeWirePathPreampNodeName(path);
  var parts = <String>[
    '"$preamp:Mult" ${eqFormatNumber(eqDbToLinear(preset.preamp))}',
  ];
  for (var i = 0; i < bands.length; i++) {
    var node = eqPipeWireBandNodeName(i, path: path);
    var band = bands[i];
    parts
      ..add('"$node:Freq" ${eqFormatNumber(band.frequency)}')
      ..add('"$node:Q" ${eqFormatNumber(band.q)}')
      ..add(
        '"$node:Gain" ${eqFormatNumber(band.type.hasGain ? band.gain : 0)}',
      );
  }
  return '{ params = [ ${parts.join(' ')} ] }';
}

/// The controls of a crossfade chain moving its mix to [mix]: the
/// `Props` value of a `pw-cli set-param` on the filter node. Each gain
/// reaches its new value smoothly (about 25 ms, [eqPipeWireGainSmoothing]).
String formatEqPipeWireMixParams(EqPipeWireMix mix) {
  var gains = mix.gains;
  return '{ params = [ ${[for (var i = 0; i < 3; i++) '"${eqPipeWireGainNodeNames[i]}:Offset" ${eqFormatNumber(gains[i])}'].join(' ')} ] }';
}
