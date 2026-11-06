import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tekartik_audio_input_flutter/audio_input_flutter.dart';

import 'colors.dart';
import 'listening.dart';

/// The texts of a [PitchListeningControl] (English by default; an app
/// passes its translations).
class PitchListeningLabels {
  /// The start button.
  final String start;

  /// The stop button.
  final String stop;

  /// Shown when the microphone is not allowed.
  final String denied;

  /// Shown when there is no microphone or it failed.
  final String failed;

  /// Shown when the sound clips.
  final String tooLoud;

  /// The texts.
  const PitchListeningLabels({
    this.start = 'Start listening',
    this.stop = 'Stop',
    this.denied =
        'The microphone is not allowed: allow it in the settings, then try '
        'again.',
    this.failed = 'No microphone found.',
    this.tooLoud = 'Too loud: move back a little.',
  });
}

/// Starts and stops a [PitchListening]: a start button when off (with
/// [intro], or why it failed), a progress while starting, the level of
/// the sound and a stop button when on (with [child] above them).
class PitchListeningControl extends StatelessWidget {
  /// The listening.
  final PitchListening listening;

  /// What listening is for, shown before it starts.
  final String? intro;

  /// Shown above the level while listening.
  final Widget? child;

  /// The texts.
  final PitchListeningLabels labels;

  /// The colors, the theme's by default.
  final PitchColors? colors;

  /// The colors of the level, the theme's by default.
  final AudioLevelColors? levelColors;

  /// A control of [listening], [intro] before it starts, [child] while on,
  /// [labels], [colors] and [levelColors] or the defaults.
  const PitchListeningControl({
    super.key,
    required this.listening,
    this.intro,
    this.child,
    this.labels = const PitchListeningLabels(),
    this.colors,
    this.levelColors,
  });

  @override
  Widget build(BuildContext context) {
    var colors = this.colors ?? PitchColors.of(context);
    return ValueListenableBuilder<AudioInputState>(
      valueListenable: listening.state,
      builder: (context, state, _) {
        switch (state) {
          case AudioInputState.on:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?child,
                const SizedBox(height: 8),
                ValueListenableBuilder<AudioLevel>(
                  valueListenable: listening.level,
                  builder: (context, level, _) {
                    var clipped = level.clipped;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            AudioLevelMic(level: level, size: 20),
                            const SizedBox(width: 4),
                            Expanded(
                              child: AudioLevelBar(
                                key: const ValueKey('pitch_level'),
                                level: level,
                                colors: levelColors,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              key: const ValueKey('pitch_stop'),
                              icon: const Icon(Icons.mic_off_outlined),
                              label: Text(labels.stop),
                              onPressed: () => unawaited(listening.stop()),
                            ),
                          ],
                        ),
                        if (clipped)
                          Text(
                            labels.tooLoud,
                            key: const ValueKey('pitch_too_loud'),
                            style: TextStyle(color: colors.off, fontSize: 12),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          case AudioInputState.starting:
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          case AudioInputState.off:
          case AudioInputState.denied:
          case AudioInputState.failed:
            var problem = switch (state) {
              AudioInputState.denied => labels.denied,
              AudioInputState.failed => labels.failed,
              _ => null,
            };
            var text = problem ?? intro;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (text != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        problem == null ? Icons.mic_none : Icons.mic_off,
                        color: problem == null ? colors.accent : colors.off,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          key: const ValueKey('pitch_intro'),
                          style: TextStyle(color: colors.muted, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (listening.input != null)
                  FilledButton.icon(
                    key: const ValueKey('pitch_start'),
                    icon: const Icon(Icons.mic),
                    label: Text(labels.start),
                    onPressed: () => unawaited(listening.start()),
                  ),
              ],
            );
        }
      },
    );
  }
}
