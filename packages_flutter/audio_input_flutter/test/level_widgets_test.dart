import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_audio_input_flutter/audio_input_flutter.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

AudioLevel _level(double amplitude, {bool clipped = false}) => AudioLevel(
  rms: amplitude,
  peak: amplitude,
  display: amplitude,
  heldPeak: amplitude,
  clipped: clipped,
);

void main() {
  group('level widgets', () {
    testWidgets('bar, mic, colors', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            AudioLevelBar(level: _level(0.1)),
            const AudioLevelBar(level: AudioLevel.silence),
            AudioLevelMic(level: _level(1, clipped: true)),
            const AudioLevelMic(level: AudioLevel.silence),
          ],
        ),
      );
      expect(find.bySemanticsLabel('-20 dB'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      var colors = AudioLevelColors.of(
        tester.element(find.byType(AudioLevelBar).first),
      );
      expect(colors.of(_level(0.1)), colors.good);
      expect(colors.of(_level(0.001)), colors.quiet);
      expect(colors.of(_level(1, clipped: true)), colors.clipped);
      expect(
        colors,
        AudioLevelColors.of(tester.element(find.byType(AudioLevelBar).first)),
      );
    });

    testWidgets('a bar narrower than 2 px', (tester) async {
      for (var width in [0.0, 0.5, 1.5, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: width,
                child: AudioLevelBar(level: _level(0.5)),
              ),
            ),
          ),
        );
        // Was an ArgumentError from the peak line under 2 px.
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    });

    testWidgets('following a metered input', (tester) async {
      var input = AudioInputPush(sampleRate: 8000);
      var metered = AudioInputMetered(input);
      await _pump(tester, AudioInputLevelBar(input: metered));
      expect(find.bySemanticsLabel(RegExp('dB')), findsNothing);
      var chunks = await metered.start();
      var subscription = chunks.listen((_) {});
      input.push(
        Float32List.fromList([
          for (var i = 0; i < 800; i++) 0.1 * math.sin(i / 3),
        ]),
      );
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp(r'-2\d dB')), findsOneWidget);
      // Not awaited: a cancel future awaited in a widget test hangs the
      // awaits after it (a completed root zone future).
      unawaited(subscription.cancel());
      await metered.stop();
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('dB')), findsNothing);
      await metered.close();
    });
  });
}
