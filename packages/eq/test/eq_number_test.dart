import 'package:tekartik_audio_eq/audio_eq.dart';
import 'package:test/test.dart';

void main() {
  test('eqFormatNumber', () {
    expect(eqFormatNumber(105), '105');
    expect(eqFormatNumber(-6.25), '-6.25');
    expect(eqFormatNumber(0.7), '0.7');
    expect(eqFormatNumber(-0.0), '0');
  });
}
