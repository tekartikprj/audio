import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tekartik_audio_input/audio_input.dart';

/// The colors of the level widgets, from the theme by default
/// ([AudioLevelColors.of]).
class AudioLevelColors {
  /// A good level.
  final Color good;

  /// Too quiet (nothing comes in, or too far).
  final Color quiet;

  /// Clipping (too loud, too near).
  final Color clipped;

  /// The empty part of the bar.
  final Color track;

  /// The colors of the level widgets.
  const AudioLevelColors({
    required this.good,
    required this.quiet,
    required this.clipped,
    required this.track,
  });

  /// The colors of the theme of [context].
  factory AudioLevelColors.of(BuildContext context) {
    var theme = Theme.of(context);
    var scheme = theme.colorScheme;
    return AudioLevelColors(
      good: theme.brightness == Brightness.dark
          ? const Color(0xFF4CC97A)
          : const Color(0xFF1E8A4C),
      quiet: scheme.onSurfaceVariant,
      clipped: scheme.error,
      track: scheme.outlineVariant,
    );
  }

  /// The color of [level]: [clipped], [quiet] under [quietDecibels],
  /// [good] otherwise.
  Color of(AudioLevel level, {double quietDecibels = -45}) => level.clipped
      ? clipped
      : level.quiet(decibels: quietDecibels)
      ? quiet
      : good;

  @override
  bool operator ==(Object other) =>
      other is AudioLevelColors &&
      other.good == good &&
      other.quiet == quiet &&
      other.clipped == clipped &&
      other.track == track;

  @override
  int get hashCode => Object.hash(good, quiet, clipped, track);
}

/// The level of the sound in a bar from [minDecibels] to 0 dB with its held
/// peak: the color tells a good level, too quiet (under [quietDecibels])
/// or clipping.
class AudioLevelBar extends StatelessWidget {
  /// The level shown.
  final AudioLevel level;

  /// The bottom of the bar, in decibels.
  final double minDecibels;

  /// Under this, too quiet.
  final double quietDecibels;

  /// The height.
  final double height;

  /// The colors, the theme's by default.
  final AudioLevelColors? colors;

  /// A bar of [level] from [minDecibels] to 0 dB, too quiet under
  /// [quietDecibels], [height] high, [colors] or the theme's.
  const AudioLevelBar({
    super.key,
    required this.level,
    this.minDecibels = -60,
    this.quietDecibels = -45,
    this.height = 8,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    var colors = this.colors ?? AudioLevelColors.of(context);
    var decibels = level.displayDecibels;
    return Semantics(
      label: decibels.isFinite ? '${decibels.round()} dB' : null,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _LevelBarPainter(
          level: level,
          minDecibels: minDecibels,
          color: colors.of(level, quietDecibels: quietDecibels),
          colors: colors,
        ),
      ),
    );
  }
}

class _LevelBarPainter extends CustomPainter {
  final AudioLevel level;
  final double minDecibels;
  final Color color;
  final AudioLevelColors colors;

  _LevelBarPainter({
    required this.level,
    required this.minDecibels,
    required this.color,
    required this.colors,
  });

  double _position(double decibels) => decibels.isFinite
      ? ((decibels - minDecibels) / -minDecibels).clamp(0.0, 1.0)
      : 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    var radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = colors.track,
    );
    var filled = _position(level.displayDecibels) * size.width;
    if (filled > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, math.max(filled, size.height), size.height),
          radius,
        ),
        Paint()..color = color,
      );
    }
    var peak = _position(level.heldPeakDecibels) * size.width;
    if (peak > 0) {
      // Inside the bar, its 2 px wide line too when there is room (not
      // clamp(1, width - 1): it throws under 2 px).
      var x = math.min(math.max(peak, 1.0), math.max(size.width - 1, 0.0));
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = level.clipped ? colors.clipped : color
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_LevelBarPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.color != color ||
      oldDelegate.colors != colors ||
      oldDelegate.minDecibels != minDecibels;
}

/// A microphone icon pulsing with the sound: a halo growing with the
/// level, in the clipping color when too loud; a direct sign the sound
/// comes in, small enough for an app bar.
class AudioLevelMic extends StatelessWidget {
  /// The level shown.
  final AudioLevel level;

  /// The size of the icon (the halo takes up to twice it).
  final double size;

  /// The bottom of the scale, in decibels.
  final double minDecibels;

  /// The colors, the theme's by default.
  final AudioLevelColors? colors;

  /// An icon of [size] pulsing with [level] from [minDecibels], [colors]
  /// or the theme's.
  const AudioLevelMic({
    super.key,
    required this.level,
    this.size = 24,
    this.minDecibels = -60,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    var colors = this.colors ?? AudioLevelColors.of(context);
    var decibels = level.displayDecibels;
    var value = decibels.isFinite
        ? ((decibels - minDecibels) / -minDecibels).clamp(0.0, 1.0)
        : 0.0;
    var color = colors.of(level);
    var halo = size * (1 + value);
    return SizedBox.square(
      dimension: size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: halo,
            height: halo,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15 + 0.25 * value),
            ),
          ),
          Icon(
            level.quiet() ? Icons.mic_none : Icons.mic,
            size: size,
            color: color,
          ),
        ],
      ),
    );
  }
}

/// Builds with the level of a metered input, at each chunk.
class AudioInputLevelBuilder extends StatelessWidget {
  /// The input measured.
  final AudioInputMetered input;

  /// Builds with the level.
  final Widget Function(BuildContext context, AudioLevel level) builder;

  /// Builds [builder] with the level of [input].
  const AudioInputLevelBuilder({
    super.key,
    required this.input,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<AudioLevel>(
    stream: input.levels,
    initialData: input.level,
    builder: (context, snapshot) =>
        builder(context, snapshot.data ?? AudioLevel.silence),
  );
}

/// Shows the level of [input] in an [AudioLevelBar] (a shortcut of
/// [AudioInputLevelBuilder]).
class AudioInputLevelBar extends StatelessWidget {
  /// The input measured.
  final AudioInputMetered input;

  /// The height of the bar.
  final double height;

  /// The colors, the theme's by default.
  final AudioLevelColors? colors;

  /// The level bar of [input], [height] high, [colors] or the theme's.
  const AudioInputLevelBar({
    super.key,
    required this.input,
    this.height = 8,
    this.colors,
  });

  @override
  Widget build(BuildContext context) => AudioInputLevelBuilder(
    input: input,
    builder: (context, level) =>
        AudioLevelBar(level: level, height: height, colors: colors),
  );
}
