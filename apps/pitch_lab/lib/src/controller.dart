import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tekartik_pitch_flutter/pitch_flutter.dart';
import 'package:tekartik_pitch_web_worker/pitch_worker.dart';

import 'sounds.dart';

/// The ids of the analyses of the lab.
abstract final class LabIds {
  /// YIN.
  static const yin = 'yin';

  /// Autocorrelation.
  static const autocorrelation = 'autocorrelation';

  /// Harmonic product spectrum.
  static const hps = 'hps';

  /// Several notes (harmonic peeling).
  static const peeling = 'peeling';

  /// The strings of the instrument (poly tuner).
  static const strings = 'strings';

  /// The notes played (hearing).
  static const notes = 'notes';

  /// The reeds of the note held.
  static const reeds = 'reeds';

  /// The single note algorithms, compared.
  static const mono = [yin, autocorrelation, hps];
}

/// Where the sound comes from.
sealed class LabSource {
  const LabSource();
}

/// The microphone.
class LabMicrophone extends LabSource {
  /// The microphone.
  const LabMicrophone();
}

/// A computed test sound, looping in real time.
class LabTestSound extends LabSource {
  /// The sound.
  final LabSound sound;

  /// The test [sound].
  const LabTestSound(this.sound);
}

/// A WAV file, looping in real time.
class LabFile extends LabSource {
  /// The file name.
  final String name;

  /// Its bytes.
  final Uint8List bytes;

  /// The WAV file [name] of [bytes].
  const LabFile(this.name, this.bytes);
}

/// The state of the lab: the source, the listening running every analysis
/// at once, the readings steadied for the views.
class PitchLabController extends ChangeNotifier {
  /// The microphone, null when the platform has none.
  final AudioInput? microphone;

  /// The sample rate of the test sounds.
  static const sampleRate = 44100;

  /// The source.
  LabSource get source => _source;
  LabSource _source;

  /// The listening of the source.
  PitchListening get listening => _listening;
  late PitchListening _listening;

  /// A4, in Hz.
  double get a4 => _a4;
  var _a4 = 440.0;

  /// The tuning of the strings view.
  PitchTuning get tuning => _tuning;
  var _tuning = pitchTunings.first;

  /// The note steadied (YIN).
  final note = ValueNotifier<PitchReading?>(null);

  /// The strings steadied, one per string of [tuning].
  final strings = ValueNotifier<List<PitchReading?>>(const []);

  /// The reeds of the note held, kept once released.
  final reeds = ValueNotifier<PitchReeds?>(null);

  final _noteSmoother = PitchSmoother();
  late PitchSmootherBank _bank;
  final _reedsTracker = PitchReedsTracker();

  /// The lab on [microphone], on [source] (the microphone by default), the
  /// analyses in a web worker when [worker] (the default on the web).
  PitchLabController({this.microphone, LabSource? source, bool? worker})
    : _source = source ?? const LabMicrophone(),
      _worker = worker ?? kIsWeb {
    _bank = PitchSmootherBank(_tuning.pitches.length);
    _listening = _newListening();
  }

  /// True to run the analyses in a web worker (an isolate on io).
  bool get worker => _worker;
  bool _worker;

  PitchWorkerProcessor? _workerProcessor;

  /// Where the analyses run.
  PitchProcessor get processor => _worker
      ? (_workerProcessor ??= PitchWorkerProcessor())
      : PitchProcessor.local;

  /// Runs the analyses in a web worker or not, the listening restarted
  /// when on.
  Future<void> setWorker(bool worker) async {
    if (worker == _worker) {
      return;
    }
    _worker = worker;
    await setSource(_source, start: _listening.isOn);
  }

  /// The analyses run on every step.
  List<PitchAnalysis> get analyses => [
    const PitchAnalysis(LabIds.yin, YinPitchAlgorithm()),
    const PitchAnalysis(
      LabIds.autocorrelation,
      AutocorrelationPitchAlgorithm(size: 2048),
    ),
    const PitchAnalysis(LabIds.hps, HpsPitchAlgorithm()),
    const PitchAnalysis(LabIds.peeling, HarmonicPeelingPitchAlgorithm()),
    PitchAnalysis(
      LabIds.strings,
      PolyTunerPitchAlgorithm(
        targets: _tuning.frequencies(a4: _a4),
        fftSize: 32768,
      ),
    ),
    PitchAnalysis(LabIds.notes, HearingPitchAlgorithm(a4: _a4)),
    PitchAnalysis(
      LabIds.reeds,
      ReedsPitchAlgorithm(a4: _a4, source: LabIds.yin),
    ),
  ];

  AudioInput? _input(LabSource source) => switch (source) {
    LabMicrophone() => microphone,
    LabTestSound(:var sound) => AudioInputSamples(
      sound.build(sampleRate),
      sampleRate: sampleRate,
      loop: true,
    ),
    LabFile(:var bytes) => AudioInputSamples.wav(bytes, loop: true),
  };

  PitchListening _newListening() => PitchListening(
    _input(_source),
    analyses: analyses,
    a4: _a4,
    timed: true,
    processor: processor,
  )..onStep = _onStep;

  /// Listens to [source] instead (started at once when [start]); throws a
  /// [FormatException] for a file that is not a WAV.
  Future<void> setSource(LabSource source, {bool start = false}) async {
    var old = _listening;
    _source = source;
    _listening = _newListening();
    _reset();
    notifyListeners();
    unawaited(old.dispose());
    if (start) {
      await _listening.start();
    }
  }

  /// Sets A4 at [a4] Hz.
  void setA4(double a4) {
    _a4 = a4;
    _listening
      ..a4 = a4
      ..analyses = analyses;
    _reset();
    notifyListeners();
  }

  /// Sets the tuning of the strings view.
  void setTuning(PitchTuning tuning) {
    _tuning = tuning;
    _bank = PitchSmootherBank(tuning.pitches.length);
    _listening.analyses = analyses;
    strings.value = const [];
    notifyListeners();
  }

  void _reset() {
    _noteSmoother.reset();
    _bank.reset();
    _reedsTracker.clear();
    note.value = null;
    strings.value = const [];
    reeds.value = null;
  }

  void _onStep(PitchStep step) {
    var time = step.time;
    var estimate = step.result<PitchEstimate>(LabIds.yin);
    note.value = _noteSmoother.add(
      estimate?.frequency,
      estimate?.clarity ?? 0,
      time,
    );
    strings.value = _bank.add(step.result<PitchTargets>(LabIds.strings), time);
    var reeds = step.result<PitchReeds>(LabIds.reeds);
    if (reeds == null) {
      _reedsTracker.clear();
    } else {
      this.reeds.value = _reedsTracker.add(reeds);
    }
  }

  @override
  void dispose() {
    unawaited(_listening.dispose());
    unawaited(_workerProcessor?.close());
    note.dispose();
    strings.dispose();
    reeds.dispose();
    super.dispose();
  }
}
