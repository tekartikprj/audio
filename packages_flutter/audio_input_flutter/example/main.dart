import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:tekartik_audio_input_flutter/audio_input_flutter.dart';

/// A 440 Hz sine fading in and out, in real time, looped: no microphone
/// needed (in an app: `AudioInputMicrophone()` of
/// tekartik_audio_input_record).
AudioInput sineInput() {
  const sampleRate = 8000;
  return AudioInputSamples(
    Float32List.fromList([
      for (var i = 0; i < 2 * sampleRate; i++)
        sin(pi * i / (2 * sampleRate)) * sin(2 * pi * 440 * i / sampleRate),
    ]),
    sampleRate: sampleRate,
    loop: true,
  );
}

void main() => runApp(const MaterialApp(home: LevelPage()));

/// The level of an input, in an app bar icon and a bar.
class LevelPage extends StatefulWidget {
  /// The level page.
  const LevelPage({super.key});

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  /// The input measured: give it to the consumer, show its level.
  final _input = AudioInputMetered(sineInput());
  StreamSubscription<Float32List>? _subscription;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    // The consumer (an analysis, a recorder): no level comes without it.
    var chunks = await _input.start();
    _subscription = chunks.listen((_) {});
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_input.stop().then((_) => _input.close()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio level'),
        actions: [
          AudioInputLevelBuilder(
            input: _input,
            builder: (context, level) => AudioLevelMic(level: level),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        // The bar takes the whole width: in a Row, wrap it in Expanded.
        child: Column(children: [AudioInputLevelBar(input: _input)]),
      ),
    );
  }
}
