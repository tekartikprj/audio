import 'package:tekartik_audio_input/audio_input.dart';
import 'package:test/test.dart';

void main() {
  group('audio input', () {
    test('devices', () {
      const device = AudioInputDevice('1', 'Built-in');
      expect(device, const AudioInputDevice('1', 'Built-in'));
      expect(device.hashCode, const AudioInputDevice('1', 'Built-in').hashCode);
      expect(device, isNot(const AudioInputDevice('2', 'Built-in')));
      expect(device.toString(), 'AudioInputDevice(1, Built-in)');
    });

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
