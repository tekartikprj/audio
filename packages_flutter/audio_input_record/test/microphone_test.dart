import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:record_platform_interface/record_platform_interface.dart';
import 'package:tekartik_audio_input_record/audio_input_record.dart';

import 'src/fake_record_platform.dart';

void main() {
  group('microphone', () {
    test('settings', () {
      var microphone = AudioInputMicrophone();
      expect(microphone, isA<AudioInput>());
      expect(microphone.sampleRate, 44100);
      expect(microphone.latency, 0.12);
      expect(microphone.device, isNull);
      var chosen = AudioInputMicrophone(
        sampleRate: 48000,
        device: const AudioInputDevice('2', 'USB'),
        latency: 0.02,
      );
      expect(chosen.sampleRate, 48000);
      expect(chosen.latency, 0.02);
      expect(chosen.device!.label, 'USB');
    });

    group('fake platform', () {
      late RecordPlatform platform;
      late FakeRecordPlatform fake;
      setUp(() {
        platform = RecordPlatform.instance;
        RecordPlatform.instance = fake = FakeRecordPlatform();
      });
      tearDown(() {
        RecordPlatform.instance = platform;
      });

      test('start, stop', () async {
        var microphone = AudioInputMicrophone();
        var done = Completer<void>();
        (await microphone.start()).listen((_) {}, onDone: done.complete);
        expect(fake.recording, isTrue);
        await microphone.stop();
        expect(fake.recording, isFalse);
        await done.future.timeout(const Duration(seconds: 5));
        await microphone.dispose();
      }, timeout: const Timeout(Duration(seconds: 10)));

      test('stop while starting', () async {
        var microphone = AudioInputMicrophone();
        var started = microphone.start();
        // The screen is left while the permission is asked.
        await microphone.stop();
        var done = Completer<void>();
        (await started).listen((_) {}, onDone: done.complete);
        // Was recording, the stream never ending.
        await done.future.timeout(const Duration(seconds: 5));
        expect(fake.recording, isFalse);
        await microphone.dispose();
      }, timeout: const Timeout(Duration(seconds: 10)));

      test('dispose while starting', () async {
        var microphone = AudioInputMicrophone();
        var started = microphone.start();
        await microphone.dispose();
        var done = Completer<void>();
        (await started).listen((_) {}, onDone: done.complete);
        await done.future.timeout(const Duration(seconds: 5));
        expect(fake.recording, isFalse);
      }, timeout: const Timeout(Duration(seconds: 10)));
    });
  });
}
