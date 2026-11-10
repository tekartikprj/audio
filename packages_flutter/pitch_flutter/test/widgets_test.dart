import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:tekartik_pitch_flutter/pitch_flutter.dart';

Future<void> _pump(WidgetTester tester, Widget child, {bool dark = false}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );

const _reeds = PitchReeds(
  pitch: 69,
  reeds: [
    PitchReed(cents: -19.6, frequency: 435.05, level: 1),
    PitchReed(cents: 0, frequency: 440, level: 0.9, support: 0.6),
    PitchReed(cents: 19.6, frequency: 445.01, level: 1),
  ],
);

void main() {
  group('widgets', () {
    testWidgets('gauge, colors', (tester) async {
      await _pump(
        tester,
        const Column(children: [PitchGauge(cents: 8), PitchGauge(cents: null)]),
      );
      expect(find.bySemanticsLabel('8 cents'), findsOneWidget);
      var context = tester.element(find.byType(PitchGauge).first);
      var colors = PitchColors.of(context);
      expect(colors, PitchColors.of(context));
      expect(colors.forCents(2), colors.inTune);
      expect(colors.forCents(-10), colors.near);
      expect(colors.forCents(30), colors.off);
      expect(colors.forCents(null), colors.muted);
      await _pump(tester, const PitchGauge(cents: -30), dark: true);
    });

    testWidgets('reeds', (tester) async {
      await _pump(tester, const PitchReedsView(reeds: _reeds));
      expect(
        find.bySemanticsLabel(
          '−19.6 cents, 0.0 cents, +19.6 cents, 4.9 beats/s, 5.0 beats/s',
        ),
        findsOneWidget,
      );
      expect(pitchSignedCents(-0.04), '0.0');
      expect(pitchSignedCents(12.34, decimals: 0), '+12');
      // Far off reeds widen the line.
      await _pump(
        tester,
        PitchReedsView(
          reeds: const PitchReeds(
            pitch: 69,
            reeds: [PitchReed(cents: 70, frequency: 458, level: 1)],
          ),
          beatsLabel: (beats) => '$beats',
        ),
      );
    });

    testWidgets('strings', (tester) async {
      await _pump(
        tester,
        const PitchStringsView(
          strings: [
            PitchStringState('E2', cents: -12.4),
            PitchStringState('A2', cents: 1, stable: true),
            PitchStringState('D3'),
          ],
        ),
      );
      expect(find.text('E2'), findsOneWidget);
      expect(find.text('−12'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('–'), findsOneWidget);
    });

    testWidgets('strings repaint on a new range or zone in tune', (
      tester,
    ) async {
      CustomPainter barPainter() => tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byKey(const ValueKey('pitch_string_0')),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      Future<void> pumpStrings({double range = 50, double inTune = 5}) => _pump(
        tester,
        PitchStringsView(
          range: range,
          inTuneCents: inTune,
          strings: const [PitchStringState('E2', cents: 10)],
        ),
      );
      await pumpStrings();
      var painter = barPainter();
      // Same cents and color, a narrower bar: the mark moves.
      await pumpStrings(range: 25);
      expect(barPainter().shouldRepaint(painter), isTrue);
      painter = barPainter();
      await pumpStrings(range: 25, inTune: 2);
      expect(barPainter().shouldRepaint(painter), isTrue);
    });

    testWidgets('listening control: start, level, too loud, stop', (
      tester,
    ) async {
      var input = AudioInputPush();
      var listening = PitchListening(
        input,
        analyses: const [PitchAnalysis('yin', YinPitchAlgorithm())],
      );
      await _pump(
        tester,
        PitchListeningControl(
          listening: listening,
          intro: 'Play a note',
          child: const Text('heard'),
        ),
      );
      expect(find.text('Play a note'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pitch_start')));
      await tester.pump();
      await tester.pump();
      expect(find.text('heard'), findsOneWidget);
      expect(find.byKey(const ValueKey('pitch_level')), findsOneWidget);
      // Full scale: clipping.
      input.push(PitchSignal.sine(440, seconds: 0.1, amplitude: 1));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('pitch_too_loud')), findsOneWidget);
      // Clipping is shown a second.
      input.push(PitchSignal.sine(440, seconds: 1.2, amplitude: 0.2));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('pitch_too_loud')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pitch_stop')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('pitch_start')), findsOneWidget);
      await listening.dispose();
    });

    testWidgets('listening control: denied, no input', (tester) async {
      var listening = PitchListening(
        null,
        analyses: const [PitchAnalysis('yin', YinPitchAlgorithm())],
      );
      await _pump(
        tester,
        PitchListeningControl(
          listening: listening,
          labels: const PitchListeningLabels(failed: 'No mic'),
        ),
      );
      expect(find.byKey(const ValueKey('pitch_start')), findsNothing);
      await listening.start();
      await tester.pump();
      expect(find.text('No mic'), findsOneWidget);
      expect(Float32List(0), isEmpty);
    });
  });
}
