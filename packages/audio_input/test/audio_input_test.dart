import 'package:tekartik_audio_input/audio_input.dart';
import 'package:test/test.dart';

void main() {
  group('audio input', () {
    test('states, errors', () {
      expect(AudioInputState.values.first, AudioInputState.off);
      expect(const AudioInputDenied().toString(), 'AudioInputDenied');
      expect(
        const AudioInputUnavailable('no device').toString(),
        'AudioInputUnavailable: no device',
      );
    });
  });
}
