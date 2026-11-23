import 'package:tekartik_audio_eq/audio_eq.dart';
import 'package:test/test.dart';

void main() {
  var preset = EqPreset(
    name: 'Two bands',
    preamp: -6.0206,
    bands: const [
      EqBand.lowShelf(105, 6),
      EqBand.peaking(1000, 3, enabled: false),
      EqBand.lowPass(16000),
    ],
  );

  group('PipeWire', () {
    test('filter chain args', () {
      var args = formatEqPipeWireFilterChainArgs(
        preset,
        nodeName: 'eq.test',
        targetObject: 'speakers',
      );
      expect(args, startsWith('{\n'));
      expect(args, endsWith('}'));
      expect(args, contains('node.description = "eq.test"'));
      expect(
        args,
        contains(
          '{ type = builtin name = eq_band_1 label = bq_lowshelf control = '
          '{ "Freq" = 105 "Q" = 0.7071067811865476 "Gain" = 6 } }',
        ),
      );
      // The disabled band is left out: the low pass is band 2.
      expect(
        args,
        contains(
          '{ type = builtin name = eq_band_2 label = bq_lowpass control = '
          '{ "Freq" = 16000 "Q" = 0.7071067811865476 "Gain" = 0 } }',
        ),
      );
      expect(args, isNot(contains('eq_band_3')));
      expect(args, contains('name = eq_preamp label = linear'));
      expect(
        args,
        contains('{ output = "eq_preamp:Out" input = "eq_band_1:In" }'),
      );
      expect(
        args,
        contains('{ output = "eq_band_1:Out" input = "eq_band_2:In" }'),
      );
      expect(args, contains('audio.position = [ FL FR ]'));
      expect(args, contains('node.name = "eq.test.output"'));
      expect(args, contains('target.object = "speakers"'));
      expect(args, contains('media.class = Audio/Sink'));
    });
    test('mono, description, no band', () {
      var args = formatEqPipeWireFilterChainArgs(
        EqPreset.flat,
        nodeName: 'x',
        description: 'Flat "quoted"',
        channels: 1,
      );
      expect(args, contains(r'node.description = "Flat \"quoted\""'));
      expect(args, contains('audio.position = [ MONO ]'));
      expect(args, contains('"Mult" = 1'));
      expect(args, isNot(contains('eq_band')));
      expect(args, isNot(contains('target.object')));
    });
    test('conf', () {
      var conf = formatEqPipeWireFilterChainConf(preset, nodeName: 'n');
      expect(conf, contains('libpipewire-module-protocol-native'));
      expect(conf, contains('{ name = libpipewire-module-filter-chain\n'));
      expect(conf, contains('            nodes = ['));
    });
    test('live params', () {
      expect(
        formatEqPipeWireParams(preset),
        startsWith(
          '{ params = [ "eq_preamp:Mult" ${eqFormatNumber(eqDbToLinear(preset.preamp))} ',
        ),
      );
      expect(
        formatEqPipeWireParams(preset),
        endsWith(
          '"eq_band_2:Freq" 16000 "eq_band_2:Q" 0.7071067811865476 '
          '"eq_band_2:Gain" 0 ] }',
        ),
      );
    });
    test('slots', () {
      var bands = eqPipeWireSlotBands(preset, slots: 4);
      expect(bands.map((b) => b.type), [
        EqFilterType.lowShelf,
        EqFilterType.lowPass,
        EqFilterType.peaking,
        EqFilterType.peaking,
      ]);
      expect(bands[3], eqPipeWireIdentityBand);
      // The identity band changes nothing.
      expect(
        EqBiquad.fromBand(eqPipeWireIdentityBand, 48000).gainDbAt(1000, 48000),
        closeTo(0, 1e-12),
      );
      expect(eqPipeWireSlotBands(preset, slots: 1).length, 2);
      var args = formatEqPipeWireFilterChainArgs(
        preset,
        nodeName: 'n',
        slots: 4,
      );
      expect(args, contains('name = eq_band_4 label = bq_peaking'));
      expect(
        formatEqPipeWireParams(preset, slots: 4),
        endsWith(
          '"eq_band_4:Freq" 1000 "eq_band_4:Q" 1 "eq_band_4:Gain" 0 ] }',
        ),
      );
      // A peaking band added in slot 3 is a live change, a shelf is not.
      var withPeaking = preset.copyWith(
        bands: [...preset.bands, const EqBand.peaking(3000, 2)],
      );
      var withShelf = preset.copyWith(
        bands: [...preset.bands, const EqBand.highShelf(8000, 2)],
      );
      expect(eqPipeWireSameChain(preset, withPeaking, slots: 4), isTrue);
      expect(eqPipeWireSameChain(preset, withShelf, slots: 4), isFalse);
      expect(eqPipeWireSameChain(preset, withPeaking), isFalse);
      expect(eqPipeWireSameChain(preset, preset), isTrue);
    });
    test('crossfade chain', () {
      var args = formatEqPipeWireFilterChainArgs(
        preset,
        nodeName: 'n',
        crossfade: true,
        mix: EqPipeWireMix.bypass,
      );
      expect(args, contains('name = eq_input label = copy'));
      // Two equalizers.
      expect(
        args,
        contains('{ output = "eq_input:Out" input = "eq_preamp:In" }'),
      );
      expect(
        args,
        contains('{ output = "eq_input:Out" input = "eq_b_preamp:In" }'),
      );
      expect(args, contains('name = eq_b_band_2 label = bq_lowpass'));
      // Each path times its smoothed gain, into the mixer.
      expect(
        args,
        contains(
          'name = eq_gain_a label = sine control = '
          '{ "Freq" = 0 "Ampl" = 0 "Offset" = 0 }',
        ),
      );
      expect(
        args,
        contains(
          'name = eq_gain_dry label = sine control = '
          '{ "Freq" = 0 "Ampl" = 0 "Offset" = 1 }',
        ),
      );
      expect(
        args,
        contains(
          'name = eq_gain_b_smooth label = bq_lowpass control = '
          '{ "Freq" = 40 "Q" = 0.5 }',
        ),
      );
      expect(
        args,
        contains('{ output = "eq_gain_a:Out" input = "eq_gain_a_smooth:In" }'),
      );
      expect(
        args,
        contains('{ output = "eq_band_2:Out" input = "eq_gain_a_mult:In 1" }'),
      );
      expect(
        args,
        contains(
          '{ output = "eq_b_band_2:Out" input = "eq_gain_b_mult:In 1" }',
        ),
      );
      expect(
        args,
        contains('{ output = "eq_input:Out" input = "eq_gain_dry_mult:In 1" }'),
      );
      expect(
        args,
        contains(
          '{ output = "eq_gain_b_smooth:Out" input = "eq_gain_b_mult:In 2" }',
        ),
      );
      expect(
        args,
        contains('{ output = "eq_gain_dry_mult:Out" input = "eq_mix:In 3" }'),
      );
      expect(args, contains('inputs = [ "eq_input:In" ]'));
      expect(args, contains('outputs = [ "eq_mix:Out" ]'));
      expect(
        formatEqPipeWireParams(preset, path: 1),
        startsWith('{ params = [ "eq_b_preamp:Mult" '),
      );
      expect(
        formatEqPipeWireParams(preset, path: 1),
        contains('"eq_b_band_1:Freq" 105'),
      );
      expect(
        formatEqPipeWireMixParams(const EqPipeWireMix(a: 0.25, b: 0.75)),
        '{ params = [ "eq_gain_a:Offset" 0.25 "eq_gain_b:Offset" 0.75 '
        '"eq_gain_dry:Offset" 0 ] }',
      );
      expect(EqPipeWireMix.path(1), EqPipeWireMix.pathB);
      // Without crossfade: one equalizer, no mixer.
      expect(
        formatEqPipeWireFilterChainArgs(preset, nodeName: 'n'),
        isNot(contains('eq_mix')),
      );
    });
  });

  group('Web Audio', () {
    test('biquad nodes', () {
      var filters = eqWebAudioFilters(
        EqPreset(
          bands: const [
            EqBand.peaking(1000, 3, q: 2),
            EqBand.lowShelf(100, 6),
            EqBand.highShelf(8000, -3),
            EqBand.lowPass(10000, q: 1),
            EqBand.highPass(30),
            EqBand.notch(50, q: 20),
            EqBand.bandPass(440, q: 5),
            EqBand.allPass(900),
            EqBand.peaking(1, 1, enabled: false),
          ],
        ),
        48000,
      );
      expect(
        [for (var f in filters) f.type],
        [
          'peaking',
          'lowshelf',
          'highshelf',
          'lowpass',
          'highpass',
          'notch',
          'bandpass',
          'allpass',
        ],
      );
      expect(filters.every((f) => f.isBiquadNode), isTrue);
      expect(filters[0].q, 2);
      expect(filters[0].gain, 3);
      // Low and high pass Q in dB.
      expect(filters[3].q, 0);
      expect(filters[4].q, closeTo(-3.0103, 1e-4));
      expect(filters[5].gain, 0);
    });
    test('a shelf of another Q is an IIR filter', () {
      var band = const EqBand.lowShelf(105, 5.6, q: 0.5);
      var filter = EqWebAudioFilter.fromBand(band, 44100);
      expect(filter.isBiquadNode, isFalse);
      var biquad = EqBiquad.fromBand(band, 44100);
      expect(filter.feedforward, [biquad.b0, biquad.b1, biquad.b2]);
      expect(filter.feedback, [1, biquad.a1, biquad.a2]);
    });
  });
}
