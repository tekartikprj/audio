import 'package:tekartik_audio_eq/audio_eq.dart';
import 'package:test/test.dart';

void main() {
  group('EqBand', () {
    test('json round trip', () {
      for (var band in [
        const EqBand.peaking(1000, -3.5, q: 1.41),
        const EqBand.lowShelf(105, 6),
        const EqBand.highPass(30, enabled: false),
        const EqBand.notch(50, q: 30),
      ]) {
        expect(EqBand.fromJson(band.toJson()), band);
      }
      expect(const EqBand.lowShelf(105, 6).toJson(), {
        'type': 'lowShelf',
        'frequency': 105.0,
        'gain': 6.0,
        'q': eqButterworthQ,
      });
      expect(
        const EqBand.peaking(1, 1, enabled: false).toJson()['enabled'],
        false,
      );
    });
    test('fromJson defaults and errors', () {
      expect(
        EqBand.fromJson({'type': 'peaking', 'frequency': 100}),
        const EqBand(type: EqFilterType.peaking, frequency: 100),
      );
      expect(
        () => EqBand.fromJson({'type': 'wobble', 'frequency': 100}),
        throwsFormatException,
      );
      expect(() => EqBand.fromJson({'type': 'peaking'}), throwsFormatException);
      expect(
        () => EqBand.fromJson({
          'type': 'peaking',
          'frequency': 100,
          'enabled': 'yes',
        }),
        throwsFormatException,
      );
    });
    test('copyWith and equality', () {
      var band = const EqBand.peaking(1000, 3);
      expect(band.copyWith(gain: 4), const EqBand.peaking(1000, 4));
      expect(band.copyWith(), band);
      expect(band.copyWith().hashCode, band.hashCode);
      expect(band, isNot(band.copyWith(enabled: false)));
    });
    test('hasGain', () {
      expect(
        [
          for (var type in EqFilterType.values)
            if (type.hasGain) type,
        ],
        [EqFilterType.peaking, EqFilterType.lowShelf, EqFilterType.highShelf],
      );
    });
  });

  group('EqPreset', () {
    test('json round trip, equality', () {
      var preset = EqPreset(
        name: 'Test',
        preamp: -4.5,
        bands: const [EqBand.lowShelf(100, 4), EqBand.peaking(3000, -2)],
      );
      var copy = EqPreset.fromJson(preset.toJson());
      expect(copy, preset);
      expect(copy.hashCode, preset.hashCode);
      expect(EqPreset.fromJson(const {}), EqPreset());
      expect(preset.copyWith(preamp: 0), isNot(preset));
      expect(
        () => EqPreset.fromJson(const {
          'bands': [1],
        }),
        throwsFormatException,
      );
    });
    test('bands unmodifiable and copied', () {
      var bands = [const EqBand.peaking(100, 1)];
      var preset = EqPreset(bands: bands);
      bands.add(const EqBand.peaking(200, 1));
      expect(preset.bands, hasLength(1));
      expect(
        () => preset.bands.add(const EqBand.peaking(1, 1)),
        throwsUnsupportedError,
      );
    });
    test('enabledBands', () {
      var preset = EqPreset(
        bands: const [
          EqBand.peaking(100, 1),
          EqBand.peaking(200, 1, enabled: false),
        ],
      );
      expect(preset.enabledBands, [const EqBand.peaking(100, 1)]);
    });
  });

  test('built in presets', () {
    expect(EqPresets.all.first, EqPreset.flat);
    expect({
      for (var p in EqPresets.all) p.name,
    }, hasLength(EqPresets.all.length));
    for (var preset in EqPresets.all) {
      // No built in preset clips more than 0.5 dB.
      expect(
        EqResponse.compute(preset).maxGain,
        lessThan(0.5),
        reason: preset.name,
      );
    }
  });

  test('eqBandwidthToQ', () {
    expect(eqBandwidthToQ(1), closeTo(1.41421, 1e-5));
    expect(eqBandwidthToQ(2), closeTo(0.66667, 1e-5));
    expect(() => eqBandwidthToQ(0), throwsArgumentError);
  });
}
