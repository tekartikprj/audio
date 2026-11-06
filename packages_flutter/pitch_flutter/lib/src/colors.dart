import 'package:material_ui/material_ui.dart';

/// The colors of the pitch widgets, from the theme by default
/// ([PitchColors.of]); an app with its own look passes its own.
class PitchColors {
  /// In tune (the needle, the marks).
  final Color inTune;

  /// A little off.
  final Color near;

  /// Far off, clipping.
  final Color off;

  /// The main marks (a reed, a string).
  final Color accent;

  /// Text.
  final Color ink;

  /// Secondary text, ticks.
  final Color muted;

  /// Lines, empty bars.
  final Color line;

  /// The colors of the pitch widgets.
  const PitchColors({
    required this.inTune,
    required this.near,
    required this.off,
    required this.accent,
    required this.ink,
    required this.muted,
    required this.line,
  });

  /// The colors of the theme of [context]: green and amber for in tune
  /// and near, the error, primary and surface colors for the rest.
  factory PitchColors.of(BuildContext context) {
    var theme = Theme.of(context);
    var scheme = theme.colorScheme;
    var dark = theme.brightness == Brightness.dark;
    return PitchColors(
      inTune: dark ? const Color(0xFF4CC97A) : const Color(0xFF1E8A4C),
      near: dark ? const Color(0xFFF2C14E) : const Color(0xFFB7791F),
      off: scheme.error,
      accent: scheme.primary,
      ink: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      line: scheme.outlineVariant,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PitchColors &&
      other.inTune == inTune &&
      other.near == near &&
      other.off == off &&
      other.accent == accent &&
      other.ink == ink &&
      other.muted == muted &&
      other.line == line;

  @override
  int get hashCode => Object.hash(inTune, near, off, accent, ink, muted, line);

  /// The color of a reading [cents] off: [inTune] within [inTuneCents],
  /// [near] within three times, [off] beyond, [muted] when null.
  Color forCents(double? cents, {double inTuneCents = 5}) {
    if (cents == null) {
      return muted;
    }
    var value = cents.abs();
    return value <= inTuneCents
        ? inTune
        : value <= 3 * inTuneCents
        ? near
        : off;
  }
}

/// The font family of the body text of [context], for painters (a text
/// style without a family draws boxes in some test harnesses).
String? pitchFontFamily(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.fontFamily;
