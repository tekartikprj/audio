import 'dart:math';
import 'dart:typed_data';

import 'package:tekartik_audio_eq/audio_eq.dart';
import 'package:test/test.dart';

const _rate = 48000.0;

Float32List _sine(double frequency, int frames, {double amplitude = 0.25}) =>
    Float32List.fromList([
      for (var i = 0; i < frames; i++)
        amplitude * sin(2 * pi * frequency * i / _rate),
    ]);

Float32List _noise(int frames, {int seed = 1}) {
  var random = Random(seed);
  return Float32List.fromList([
    for (var i = 0; i < frames; i++) random.nextDouble() * 0.5 - 0.25,
  ]);
}

/// The amplitude of the [frequency] component of [signal] from [from]
/// (a lock-in: correlation with a sine and a cosine).
double _amplitude(Float32List signal, double frequency, int from) {
  var sinSum = 0.0;
  var cosSum = 0.0;
  for (var i = from; i < signal.length; i++) {
    var phase = 2 * pi * frequency * i / _rate;
    sinSum += signal[i] * sin(phase);
    cosSum += signal[i] * cos(phase);
  }
  var count = signal.length - from;
  return 2 * sqrt(sinSum * sinSum + cosSum * cosSum) / count;
}

/// Runs [input] (one list per channel) through [processor] in blocks of
/// [block] frames, calling each change at its frame position.
List<Float32List> _run(
  EqProcessor processor,
  List<Float32List> input, {
  required int block,
  Map<int, void Function(EqProcessor processor)> changes = const {},
}) {
  var frames = input[0].length;
  var output = [for (var _ in input) Float32List(frames)];
  var positions = [...changes.keys, frames]..sort();
  var offset = 0;
  for (var position in positions) {
    while (offset < position) {
      var end = min(offset + block, position);
      processor.process(
        [for (var c in input) Float32List.sublistView(c, offset, end)],
        [for (var c in output) Float32List.sublistView(c, offset, end)],
      );
      offset = end;
    }
    changes[position]?.call(processor);
  }
  return output;
}

double _maxDifference(Float32List a, Float32List b) {
  var result = 0.0;
  for (var i = 0; i < a.length; i++) {
    result = max(result, (a[i] - b[i]).abs());
  }
  return result;
}

void main() {
  var preset = EqPreset(
    name: 'test',
    preamp: -6,
    bands: const [
      EqBand.highPass(25),
      EqBand.lowShelf(80, 5),
      EqBand.peaking(300, -4, q: 1.5),
      EqBand.peaking(2500, 6, q: 2),
      EqBand.highShelf(8000, -3),
    ],
  );

  test('flat passes the sound unchanged', () {
    var input = _noise(1000);
    var processor = EqProcessor(channels: 1, sampleRate: _rate);
    var output = _run(processor, [input], block: 128);
    expect(output[0], input);
  });

  test('a sine is changed as the response curve says', () {
    var chain = EqChain.fromPreset(preset, _rate);
    // Even frequencies: a whole number of periods in the half second
    // measured.
    for (var raw in eqLogFrequencies(20, 20, 20000)) {
      var frequency = (raw / 2).roundToDouble() * 2;
      var processor = EqProcessor(
        channels: 1,
        sampleRate: _rate,
        preset: preset,
      );
      var input = _sine(frequency, 48000);
      var output = _run(processor, [input], block: 512)[0];
      var measured = eqLinearToDb(
        _amplitude(output, frequency, 24000) /
            _amplitude(input, frequency, 24000),
      );
      expect(
        measured,
        closeTo(chain.gainDbAt(frequency), 0.05),
        reason: '$frequency Hz',
      );
    }
  });

  test('the output does not depend on the block size', () {
    var input = [_noise(20000, seed: 1), _noise(20000, seed: 2)];
    Map<int, void Function(EqProcessor)> changes() => {
      5000: (p) => p.preset = preset,
      // During the crossfade: applied when it ends.
      5100: (p) => p.preset = preset.copyWith(preamp: -3),
      12000: (p) => p.bypass = true,
      15000: (p) => p.bypass = false,
    };
    List<Float32List> run(int block) => _run(
      EqProcessor(channels: 2, sampleRate: _rate),
      input,
      block: block,
      changes: changes(),
    );
    var reference = run(20000);
    for (var block in [1, 7, 64, 256, 1000, 4096]) {
      var output = run(block);
      for (var c = 0; c < 2; c++) {
        expect(
          _maxDifference(output[c], reference[c]),
          lessThan(1e-6),
          reason: 'block $block channel $c',
        );
      }
    }
  });

  test('a change crossfades without a step', () {
    // A 1 kHz sine, then +12 dB at 1 kHz: the largest step between two
    // samples stays the one of the louder sine.
    var input = _sine(1000, 9600);
    var processor = EqProcessor(channels: 1, sampleRate: _rate);
    var output = _run(
      processor,
      [input],
      block: 480,
      changes: {
        4800: (p) =>
            p.preset = EqPreset(bands: const [EqBand.peaking(1000, 12)]),
      },
    )[0];
    var steady = 0.0;
    for (var i = 8000; i < output.length; i++) {
      steady = max(steady, (output[i] - output[i - 1]).abs());
    }
    var largest = 0.0;
    for (var i = 1; i < output.length; i++) {
      largest = max(largest, (output[i] - output[i - 1]).abs());
    }
    expect(steady, closeTo(0.25 * 3.98 * 2 * pi * 1000 / _rate, 0.01));
    expect(largest, lessThan(steady * 1.05));
  });

  test('crossfade state, pending change, bypass', () {
    var processor = EqProcessor(
      channels: 1,
      sampleRate: _rate,
      crossfadeFrames: 100,
    );
    expect(processor.isCrossfading, isFalse);
    processor.preset = preset;
    expect(processor.isCrossfading, isTrue);
    var later = preset.copyWith(preamp: 0);
    processor.preset = later;
    expect(processor.preset, later);
    var input = _noise(4000);
    _run(processor, [Float32List.sublistView(input, 0, 150)], block: 150);
    // The first crossfade ended at 100, the pending one started there.
    expect(processor.isCrossfading, isTrue);
    _run(processor, [Float32List.sublistView(input, 150, 300)], block: 150);
    expect(processor.isCrossfading, isFalse);

    // Bypass: the input itself once the crossfade is over.
    processor.bypass = true;
    expect(processor.bypass, isTrue);
    var output = _run(processor, [input], block: 333)[0];
    expect(
      Float32List.sublistView(output, 100),
      Float32List.sublistView(input, 100),
    );
  });

  test('switching at once with no crossfade', () {
    var processor = EqProcessor(
      channels: 1,
      sampleRate: _rate,
      crossfadeFrames: 0,
    );
    processor.preset = preset;
    expect(processor.isCrossfading, isFalse);
    var input = _sine(1000, 2000);
    var fresh = EqProcessor(channels: 1, sampleRate: _rate, preset: preset);
    expect(
      _run(processor, [input], block: 100)[0],
      _run(fresh, [input], block: 100)[0],
    );
  });

  test('interleaved and in place give the same output', () {
    var left = _noise(3000, seed: 3);
    var right = _noise(3000, seed: 4);
    var planar = _run(
      EqProcessor(channels: 2, sampleRate: _rate, preset: preset),
      [left, right],
      block: 300,
    );
    var interleaved = Float32List(6000);
    for (var i = 0; i < 3000; i++) {
      interleaved[i * 2] = left[i];
      interleaved[i * 2 + 1] = right[i];
    }
    var processor = EqProcessor(channels: 2, sampleRate: _rate, preset: preset);
    for (var offset = 0; offset < 6000; offset += 600) {
      var view = Float32List.sublistView(interleaved, offset, offset + 600);
      processor.processInterleaved(view, view);
    }
    for (var i = 0; i < 3000; i++) {
      expect(interleaved[i * 2], planar[0][i]);
      expect(interleaved[i * 2 + 1], planar[1][i]);
    }
    var inPlace = [Float32List.fromList(left), Float32List.fromList(right)];
    var inPlaceProcessor = EqProcessor(
      channels: 2,
      sampleRate: _rate,
      preset: preset,
    );
    for (var offset = 0; offset < 3000; offset += 300) {
      var views = [
        for (var c in inPlace) Float32List.sublistView(c, offset, offset + 300),
      ];
      inPlaceProcessor.process(views, views);
    }
    expect(inPlace, planar);
  });

  test('reset clears the state', () {
    var processor = EqProcessor(channels: 1, sampleRate: _rate, preset: preset);
    _run(processor, [_noise(1000)], block: 1000);
    processor.reset();
    var silence = _run(processor, [Float32List(500)], block: 500)[0];
    expect(silence, everyElement(0));
  });

  test('invalid', () {
    expect(
      () => EqProcessor(channels: 0, sampleRate: _rate),
      throwsArgumentError,
    );
    var processor = EqProcessor(channels: 2, sampleRate: _rate);
    expect(
      () => processor.process([Float32List(10)], [Float32List(10)]),
      throwsArgumentError,
    );
    expect(
      () => processor.process(
        [Float32List(10), Float32List(9)],
        [Float32List(10), Float32List(10)],
      ),
      throwsArgumentError,
    );
    expect(
      () => processor.processInterleaved(Float32List(9), Float32List(9)),
      throwsArgumentError,
    );
    expect(
      () => processor.preset = EqPreset(
        bands: const [EqBand.peaking(100, 1, q: 0)],
      ),
      throwsArgumentError,
    );
    expect(processor.preset, EqPreset.flat);
    expect(processor.isCrossfading, isFalse);
  });
}
