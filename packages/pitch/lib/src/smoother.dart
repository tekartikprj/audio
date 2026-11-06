import 'dart:math' as math;

import 'pitch_math.dart';
import 'result.dart';

/// A pitch steadied over the last readings, with how steady it is: what a
/// display needs to show a needle and to tell when the note is settled.
class PitchReading {
  /// The frequency steadied, in Hz.
  final double frequency;

  /// The spread of the readings kept, in cents: their median absolute
  /// deviation from their median (0 for a steady note).
  final double spread;

  /// The readings kept.
  final int count;

  /// The seconds the same note has been held (the readings rounding to
  /// the same note, without a gap emptying the window).
  final double held;

  /// [frequency] steadied in Hz, its readings [spread] cents apart,
  /// [count] of them, the note [held] seconds.
  const PitchReading({
    required this.frequency,
    required this.spread,
    required this.count,
    required this.held,
  });

  /// True when settled: at least [minCount] readings within [maxSpread]
  /// cents, the note held [minHeld] seconds.
  bool stable({double maxSpread = 2, double minHeld = 0.3, int minCount = 3}) =>
      count >= minCount && spread <= maxSpread && held >= minHeld;

  /// The MIDI pitch with its fraction, A4 at [a4] Hz.
  double pitch({double a4 = 440}) => pitchOfFrequency(frequency, a4: a4);

  /// The nearest MIDI note, A4 at [a4] Hz.
  int note({double a4 = 440}) => pitch(a4: a4).round();

  /// The cents from the nearest note (-50 to 50), A4 at [a4] Hz.
  double cents({double a4 = 440}) {
    var value = pitch(a4: a4);
    return (value - value.round()) * 100;
  }

  @override
  String toString() =>
      'PitchReading(${frequency.toStringAsFixed(2)} Hz, '
      'spread ${spread.toStringAsFixed(2)} cents, $count, '
      'held ${held.toStringAsFixed(2)} s)';
}

/// Steadies a pitch read again and again: the median of the last
/// [maxWindowSeconds] (robust to octave jumps and outliers), followed by an
/// exponential average (a needle moving smoothly), with how steady it is
/// ([PitchReading]).
class PitchSmoother {
  /// The seconds of readings kept for the median.
  final double maxWindowSeconds;

  /// How fast the average follows the median, 0 to 1 (higher: faster,
  /// more jitter).
  final double alpha;

  /// The clarity a reading needs to count.
  final double minClarity;

  final _window = <({double frequency, double time})>[];
  double? _average;
  PitchReading? _reading;
  double? _since;
  int? _note;

  /// A smoother keeping [maxWindowSeconds] of readings with at least
  /// [minClarity], its average following the median at [alpha].
  PitchSmoother({
    this.maxWindowSeconds = 1,
    this.alpha = 0.25,
    this.minClarity = 0.2,
  });

  /// The frequency steadied (Hz), null when nothing was heard recently.
  double? get frequency => _reading?.frequency;

  /// The last reading, null when nothing was heard recently.
  PitchReading? get reading => _reading;

  /// Adds a reading: [frequency] in Hz (null: nothing heard) with its
  /// [clarity], at [time] in seconds; returns the reading steadied, null
  /// when nothing was heard within the window.
  PitchReading? add(double? frequency, double clarity, double time) {
    _window.removeWhere((reading) => reading.time < time - maxWindowSeconds);
    if (frequency != null && frequency > 0 && clarity >= minClarity) {
      _window.add((frequency: frequency, time: time));
    }
    if (_window.isEmpty) {
      _average = null;
      _since = null;
      _note = null;
      return _reading = null;
    }
    var median = _median([for (var reading in _window) reading.frequency]);
    var average = _average;
    average = _average = average == null
        ? median
        : average + alpha * (median - average);
    var note = pitchOfFrequency(median).round();
    if (note != _note) {
      _note = note;
      _since = _window.last.time;
    }
    var spread = _median([
      for (var reading in _window) pitchCents(median, reading.frequency).abs(),
    ]);
    return _reading = PitchReading(
      frequency: average,
      spread: spread,
      count: _window.length,
      held: math.max(0, time - (_since ?? time)),
    );
  }

  static double _median(List<double> values) {
    values.sort();
    var middle = values.length ~/ 2;
    return values.length.isOdd
        ? values[middle]
        : (values[middle - 1] + values[middle]) / 2;
  }

  /// Forgets the readings.
  void reset() {
    _window.clear();
    _average = null;
    _reading = null;
    _since = null;
    _note = null;
  }
}

/// One [PitchSmoother] per target (the strings of an instrument).
class PitchSmootherBank {
  /// The smoothers, one per target.
  final List<PitchSmoother> smoothers;

  /// [count] smoothers with the settings of [PitchSmoother].
  PitchSmootherBank(
    int count, {
    double maxWindowSeconds = 1,
    double alpha = 0.25,
    double minClarity = 0.2,
  }) : smoothers = List.generate(
         count,
         (_) => PitchSmoother(
           maxWindowSeconds: maxWindowSeconds,
           alpha: alpha,
           minClarity: minClarity,
         ),
       );

  /// Adds the reading of each target of [targets] (in order) at [time] in
  /// seconds, a target counting only when it sounds (at least [minLevel]
  /// of the loudest one); returns the readings steadied.
  List<PitchReading?> add(
    PitchTargets? targets,
    double time, {
    double minLevel = 0.1,
  }) => [
    for (var (index, smoother) in smoothers.indexed)
      () {
        var target = targets != null && index < targets.targets.length
            ? targets.targets[index]
            : null;
        var sounds = target != null && target.level >= minLevel;
        return smoother.add(
          sounds ? target.frequency : null,
          sounds ? target.clarity : 0,
          time,
        );
      }(),
  ];

  /// Forgets the readings.
  void reset() {
    for (var smoother in smoothers) {
      smoother.reset();
    }
  }
}

/// Steadies the reeds of a held note: the median of each reed over the
/// last [length] analyses that found the same note and the same number of
/// reeds.
class PitchReedsTracker {
  /// The analyses kept.
  final int length;

  final _recent = <PitchReeds>[];

  /// A tracker keeping the last [length] analyses.
  PitchReedsTracker({this.length = 5});

  /// The analyses the reeds steadied come from.
  int get count => _recent.length;

  /// The reeds steadied, null when nothing is held. The uncertainty of
  /// each reed is the larger of its median uncertainty and the spread of
  /// its cents over the analyses kept (a pitch moving with the bellows).
  PitchReeds? get current {
    if (_recent.isEmpty) {
      return null;
    }
    var last = _recent.last;
    return PitchReeds(
      pitch: last.pitch,
      reeds: [
        for (var i = 0; i < last.reeds.length; i++)
          () {
            var cents = [for (var reeds in _recent) reeds.reeds[i].cents];
            var median = PitchSmoother._median(List.of(cents));
            var spread = PitchSmoother._median([
              for (var value in cents) (value - median).abs(),
            ]);
            return PitchReed(
              cents: median,
              frequency: PitchSmoother._median([
                for (var reeds in _recent) reeds.reeds[i].frequency,
              ]),
              level: PitchSmoother._median([
                for (var reeds in _recent) reeds.reeds[i].level,
              ]),
              uncertainty: math.max(
                spread,
                PitchSmoother._median([
                  for (var reeds in _recent) reeds.reeds[i].uncertainty,
                ]),
              ),
              support: PitchSmoother._median([
                for (var reeds in _recent) reeds.reeds[i].support,
              ]),
            );
          }(),
      ],
      harmonics: last.harmonics,
      size: last.size,
    );
  }

  /// Adds an analysis (null: nothing heard, the note is forgotten);
  /// returns the reeds steadied.
  PitchReeds? add(PitchReeds? reeds) {
    if (reeds == null) {
      _recent.clear();
      return null;
    }
    var last = _recent.lastOrNull;
    if (last != null &&
        (last.pitch != reeds.pitch ||
            last.reeds.length != reeds.reeds.length)) {
      _recent.clear();
    }
    _recent.add(reeds);
    if (_recent.length > length) {
      _recent.removeAt(0);
    }
    return current;
  }

  /// Forgets the note.
  void clear() => _recent.clear();
}
