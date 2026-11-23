// A player for the tests: `dart fake_player.dart <file>`, its behavior set
// by FAKE_PLAYER_MODE: `copy` copies the file to FAKE_PLAYER_OUT, `wait`
// waits 30 s (to be stopped), `fail` writes to stderr and exits with 3.
import 'dart:io';

Future<void> main(List<String> args) async {
  var env = Platform.environment;
  switch (env['FAKE_PLAYER_MODE']) {
    case 'copy':
      await File(args.single).copy(env['FAKE_PLAYER_OUT']!);
    case 'wait':
      await Future<void>.delayed(const Duration(seconds: 30));
    case 'fail':
      stderr.writeln('no device');
      exitCode = 3;
  }
}
