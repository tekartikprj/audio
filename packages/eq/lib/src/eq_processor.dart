import 'dart:math';
import 'dart:typed_data';

import 'eq_band.dart';
import 'eq_biquad.dart';

/// The reference equalizer processor: a [preset] applied to blocks of PCM
/// (`Float32List` per channel, about -1 to 1), in `double` precision.
///
/// Transposed direct form II, one state per band and channel. A change of
/// [preset] or [bypass] does not click: the new chain starts from the state
/// of the old one (band by band, by position in the preset) and the two run
/// side by side while the output crossfades over [crossfadeFrames] frames. A
/// change made during a crossfade is applied when it ends (the latest one
/// wins). The output does not depend on how the sound is cut into blocks.
///
/// Used offline (a WAV file), in an app's own sound and as the oracle of a
/// native engine.
class EqProcessor {
  /// The number of channels of each block.
  final int channels;

  /// The sample rate in Hz.
  final double sampleRate;

  /// The length of a crossfade after a change, in frames (0: switch at
  /// once).
  final int crossfadeFrames;

  EqPreset _preset;
  var _bypass = false;
  late _Cascade _current;
  _Cascade? _old;
  _Cascade? _pending;
  var _fadePosition = 0;
  var _scratch = Float64List(0);
  var _scratchOld = Float64List(0);
  List<Float32List> _interleaveBuffers = const [];

  /// A processor of [channels] channels (1 or more) at [sampleRate] Hz,
  /// starting with [preset] (flat by default). Throws an [ArgumentError] on
  /// an invalid argument or band (see [EqBiquad.fromBand]).
  EqProcessor({
    required this.channels,
    required this.sampleRate,
    EqPreset? preset,
    this.crossfadeFrames = 256,
  }) : _preset = preset ?? EqPreset.flat {
    if (channels < 1) {
      throw ArgumentError.value(channels, 'channels', 'must be 1 or more');
    }
    if (crossfadeFrames < 0) {
      throw ArgumentError.value(crossfadeFrames, 'crossfadeFrames');
    }
    _current = _compile();
  }

  /// The preset applied (unless [bypass]). Setting it starts a crossfade;
  /// an invalid band throws an [ArgumentError] and changes nothing.
  EqPreset get preset => _preset;

  set preset(EqPreset value) {
    if (value == _preset) {
      return;
    }
    var previous = _preset;
    _preset = value;
    try {
      _change(_compile());
    } catch (_) {
      _preset = previous;
      rethrow;
    }
  }

  /// Whether the sound goes through unchanged (preamp and bands off), for
  /// an A/B comparison. Setting it starts a crossfade.
  bool get bypass => _bypass;

  set bypass(bool value) {
    if (value == _bypass) {
      return;
    }
    _bypass = value;
    _change(_compile());
  }

  /// Whether a crossfade is running (the last change is not fully heard
  /// yet).
  bool get isCrossfading => _old != null;

  _Cascade _compile() {
    if (_bypass) {
      return _Cascade.bypass(_preset.bands.length, channels);
    }
    return _Cascade(
      [
        for (var band in _preset.bands)
          if (band.enabled) EqBiquad.fromBand(band, sampleRate) else null,
      ],
      eqDbToLinear(_preset.preamp),
      channels,
    );
  }

  void _change(_Cascade next) {
    if (_old != null) {
      _pending = next;
      return;
    }
    _start(next);
  }

  void _start(_Cascade next) {
    next.copyStateFrom(_current);
    _pending = null;
    if (crossfadeFrames == 0) {
      _current = next;
      return;
    }
    _old = _current;
    _current = next;
    _fadePosition = 0;
  }

  /// Clears the filter states and ends any crossfade (the last change is
  /// heard at once), e.g. after a seek.
  void reset() {
    var pending = _pending;
    if (pending != null) {
      _current = pending;
    }
    _old = null;
    _pending = null;
    _current.clearState();
  }

  /// Processes one block: [input] and [output] hold one list per channel,
  /// all of the same length; [output] may be [input] (in place). Throws an
  /// [ArgumentError] on a wrong channel count or length.
  void process(List<Float32List> input, List<Float32List> output) {
    if (input.length != channels || output.length != channels) {
      throw ArgumentError(
        'Expected $channels channels, got ${input.length} in, ${output.length} out',
      );
    }
    var frames = input[0].length;
    for (var c = 0; c < channels; c++) {
      if (input[c].length != frames || output[c].length != frames) {
        throw ArgumentError('Every channel must have $frames frames');
      }
    }
    if (_scratch.length < frames) {
      _scratch = Float64List(frames);
      _scratchOld = Float64List(frames);
    }
    var offset = 0;
    while (offset < frames) {
      var old = _old;
      if (old == null) {
        var count = frames - offset;
        for (var c = 0; c < channels; c++) {
          _current.run(c, input[c], offset, count, _scratch);
          var out = output[c];
          for (var i = 0; i < count; i++) {
            out[offset + i] = _scratch[i];
          }
        }
        offset = frames;
      } else {
        var count = min(frames - offset, crossfadeFrames - _fadePosition);
        for (var c = 0; c < channels; c++) {
          old.run(c, input[c], offset, count, _scratchOld);
          _current.run(c, input[c], offset, count, _scratch);
          var out = output[c];
          for (var i = 0; i < count; i++) {
            var weight = (_fadePosition + i + 1) / crossfadeFrames;
            var before = _scratchOld[i];
            out[offset + i] = before + (_scratch[i] - before) * weight;
          }
        }
        _fadePosition += count;
        offset += count;
        if (_fadePosition >= crossfadeFrames) {
          _old = null;
          var pending = _pending;
          if (pending != null) {
            _start(pending);
          }
        }
      }
    }
    _current.flushDenormals();
    _old?.flushDenormals();
  }

  /// Processes one block of interleaved frames (`L R L R...` for 2
  /// channels): [input] and [output] have the same length, a multiple of
  /// [channels]; [output] may be [input].
  void processInterleaved(Float32List input, Float32List output) {
    if (input.length != output.length || input.length % channels != 0) {
      throw ArgumentError('Lengths must match and be a multiple of $channels');
    }
    var frames = input.length ~/ channels;
    if (_interleaveBuffers.isEmpty || _interleaveBuffers[0].length != frames) {
      _interleaveBuffers = [
        for (var c = 0; c < channels; c++) Float32List(frames),
      ];
    }
    for (var c = 0; c < channels; c++) {
      var buffer = _interleaveBuffers[c];
      for (var i = 0; i < frames; i++) {
        buffer[i] = input[i * channels + c];
      }
    }
    process(_interleaveBuffers, _interleaveBuffers);
    for (var c = 0; c < channels; c++) {
      var buffer = _interleaveBuffers[c];
      for (var i = 0; i < frames; i++) {
        output[i * channels + c] = buffer[i];
      }
    }
  }
}

/// A compiled chain with its state: one slot per band of the preset (null
/// for a disabled band, kept so that states stay aligned by position).
class _Cascade {
  final int channels;
  final int slots;
  final double gain;

  /// 5 coefficients per slot: b0 b1 b2 a1 a2.
  final Float64List coefficients;

  /// Whether each slot is applied.
  final List<bool> active;

  /// 2 values (z1 z2) per slot and channel: `(channel * slots + slot) * 2`.
  final Float64List state;

  _Cascade(List<EqBiquad?> biquads, this.gain, this.channels)
    : slots = biquads.length,
      coefficients = Float64List(biquads.length * 5),
      active = [for (var biquad in biquads) biquad != null],
      state = Float64List(biquads.length * channels * 2) {
    for (var s = 0; s < slots; s++) {
      var biquad = biquads[s] ?? EqBiquad.identity;
      coefficients
        ..[s * 5] = biquad.b0
        ..[s * 5 + 1] = biquad.b1
        ..[s * 5 + 2] = biquad.b2
        ..[s * 5 + 3] = biquad.a1
        ..[s * 5 + 4] = biquad.a2;
    }
  }

  _Cascade.bypass(int slots, int channels)
    : this(List<EqBiquad?>.filled(slots, null), 1, channels);

  /// Runs [count] frames of channel [c] of [input] from [offset] into
  /// [out] (from 0).
  void run(int c, Float32List input, int offset, int count, Float64List out) {
    for (var i = 0; i < count; i++) {
      out[i] = input[offset + i] * gain;
    }
    for (var s = 0; s < slots; s++) {
      if (!active[s]) {
        continue;
      }
      var k = s * 5;
      var b0 = coefficients[k];
      var b1 = coefficients[k + 1];
      var b2 = coefficients[k + 2];
      var a1 = coefficients[k + 3];
      var a2 = coefficients[k + 4];
      var z = (c * slots + s) * 2;
      var z1 = state[z];
      var z2 = state[z + 1];
      for (var i = 0; i < count; i++) {
        var x = out[i];
        var y = b0 * x + z1;
        z1 = b1 * x - a1 * y + z2;
        z2 = b2 * x - a2 * y;
        out[i] = y;
      }
      state[z] = z1;
      state[z + 1] = z2;
    }
  }

  /// Takes the state of [other] slot by slot, where both slots are active.
  void copyStateFrom(_Cascade other) {
    for (var c = 0; c < channels && c < other.channels; c++) {
      for (var s = 0; s < slots; s++) {
        var z = (c * slots + s) * 2;
        var keep = s < other.slots && active[s] && other.active[s];
        if (keep) {
          var zOther = (c * other.slots + s) * 2;
          state[z] = other.state[zOther];
          state[z + 1] = other.state[zOther + 1];
        } else {
          state[z] = 0;
          state[z + 1] = 0;
        }
      }
    }
  }

  void clearState() => state.fillRange(0, state.length, 0);

  /// States below 1e-30 become 0: a decaying filter never reaches the slow
  /// subnormal numbers.
  void flushDenormals() {
    for (var i = 0; i < state.length; i++) {
      if (state[i].abs() < 1e-30) {
        state[i] = 0;
      }
    }
  }
}
