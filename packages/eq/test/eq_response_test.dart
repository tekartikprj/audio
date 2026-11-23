import 'package:tekartik_audio_eq/audio_eq.dart';
import 'package:test/test.dart';

void main() {
  test('eqLogFrequencies', () {
    var frequencies = eqLogFrequencies(4, 10, 10000);
    expect(frequencies, hasLength(4));
    expect(frequencies.first, 10);
    expect(frequencies.last, 10000);
    expect(frequencies[1], closeTo(100, 1e-9));
    expect(frequencies[2], closeTo(1000, 1e-9));
  });

  test('flat and preamp', () {
    var flat = EqResponse.compute(EqPreset.flat, points: 16);
    expect(flat.frequencies, hasLength(16));
    expect(flat.gains, everyElement(0));
    var quieter = EqResponse.compute(EqPreset(preamp: -6), points: 8);
    expect(quieter.gains, everyElement(closeTo(-6, 1e-9)));
    expect(
      EqResponse.compute(
        EqPreset(preamp: -6),
        points: 8,
        includePreamp: false,
      ).gains,
      everyElement(0),
    );
  });

  test('min and max', () {
    var response = EqResponse.compute(
      EqPreset(bands: const [EqBand.peaking(100, 6), EqBand.peaking(5000, -4)]),
      points: 1024,
    );
    expect(response.maxGain, closeTo(6, 0.01));
    expect(response.minGain, closeTo(-4, 0.01));
  });

  test('eqAutoPreamp', () {
    expect(eqAutoPreamp(EqPreset.flat), 0);
    expect(eqAutoPreamp(EqPreset(bands: const [EqBand.peaking(1000, -6)])), 0);
    expect(
      eqAutoPreamp(
        EqPreset(preamp: 10, bands: const [EqBand.lowShelf(105, 6)]),
      ),
      closeTo(-6, 0.01),
    );
    // Two overlapping boosts add up.
    expect(
      eqAutoPreamp(
        EqPreset(
          bands: const [
            EqBand.peaking(1000, 4, q: 0.5),
            EqBand.peaking(1200, 4, q: 0.5),
          ],
        ),
      ),
      lessThan(-7.5),
    );
  });

  test('invalid', () {
    expect(
      () => EqResponse.compute(EqPreset.flat, points: 1),
      throwsArgumentError,
    );
    expect(
      () => EqResponse.compute(
        EqPreset.flat,
        minFrequency: 100,
        maxFrequency: 100,
      ),
      throwsArgumentError,
    );
  });
}
