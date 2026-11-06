import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_audio_input_record/audio_input_record.dart';

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
  });
}
