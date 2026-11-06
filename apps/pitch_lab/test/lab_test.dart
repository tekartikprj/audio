import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pitch_lab/src/app.dart';
import 'package:pitch_lab/src/controller.dart';
import 'package:pitch_lab/src/sounds.dart';
import 'package:tekartik_pitch/pitch_signal.dart';
import 'package:tekartik_pitch_flutter/pitch_flutter.dart';

Future<void> _hear(
  WidgetTester tester,
  AudioInputPush input,
  Float32List samples,
) async {
  for (var start = 0; start < samples.length; start += 4096) {
    var end = math.min(start + 4096, samples.length);
    input.push(Float32List.sublistView(samples, start, end));
    await tester.pump();
  }
  await tester.pump();
}

void main() {
  testWidgets('a musette heard: note, reeds, notes, compare', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var microphone = AudioInputPush();
    var controller = PitchLabController(microphone: microphone);
    await tester.pumpWidget(PitchLabApp(controller: controller));
    expect(find.text('Pitch lab'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pitch_start')));
    await tester.pump();
    await tester.pump();
    expect(microphone.started, isTrue);
    await _hear(
      tester,
      microphone,
      PitchSignal.reeds(440, [-19.6, 0, 19.6], seconds: 1.5),
    );
    // The note.
    expect(find.text('A4'), findsOneWidget);
    expect(find.byKey(const ValueKey('note_cents')), findsOneWidget);
    // The reeds.
    await tester.tap(find.byKey(const ValueKey('view_reeds')));
    await tester.pump();
    expect(find.text('3 reeds · A4'), findsOneWidget);
    // The notes played.
    await tester.tap(find.byKey(const ValueKey('view_notes')));
    await tester.pump();
    expect(find.byIcon(Icons.check), findsWidgets);
    // The algorithms compared.
    await tester.tap(find.byKey(const ValueKey('view_compare')));
    await tester.pump();
    expect(find.byKey(const ValueKey('compare_table')), findsOneWidget);
    expect(find.text('In an isolate'), findsOneWidget);
    expect(find.text('The analyses run on the main thread'), findsOneWidget);
    expect(find.text('yin'), findsWidgets);
    expect(find.textContaining('Total '), findsOneWidget);
    // A4 at 442: set at once.
    controller.setA4(442);
    await tester.pump();
    expect(find.text('A4 = 442 Hz'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pitch_stop')));
    await tester.pump();
    await tester.pump();
    expect(microphone.started, isFalse);
    controller.dispose();
  });

  testWidgets('the strings of a guitar, the test sounds', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var microphone = AudioInputPush();
    var controller = PitchLabController(microphone: microphone);
    await tester.pumpWidget(PitchLabApp(controller: controller));
    await tester.tap(find.byKey(const ValueKey('view_strings')));
    await tester.pump();
    expect(find.text('E2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pitch_start')));
    await tester.pump();
    await tester.pump();
    var chord = labSounds.firstWhere((sound) => sound.id == 'guitar_chord');
    await _hear(tester, microphone, chord.build(44100));
    expect(find.textContaining('Notes found'), findsOneWidget);
    expect(controller.strings.value.whereType<PitchReading>(), isNotEmpty);
    // Every test sound computes.
    for (var sound in labSounds) {
      expect(sound.build(8000), isNotEmpty, reason: sound.id);
    }
    // Another tuning.
    controller.setTuning(PitchTuning.byId('ukulele')!);
    await tester.pump();
    expect(find.text('G4'), findsWidgets);
    await controller.setSource(const LabMicrophone());
    controller.dispose();
  });
}
