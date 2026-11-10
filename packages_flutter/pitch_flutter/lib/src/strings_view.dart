import 'package:material_ui/material_ui.dart';

import 'colors.dart';
import 'reeds_view.dart';

/// A string of an instrument as shown by [PitchStringsView].
class PitchStringState {
  /// Its name (`E2`).
  final String name;

  /// How many cents it is off, null when it does not sound.
  final double? cents;

  /// True when the reading is settled (a lock mark).
  final bool stable;

  /// The string [name], [cents] off (null when silent), [stable] or not.
  const PitchStringState(this.name, {this.cents, this.stable = false});
}

/// The strings of an instrument, one row each: its name, a bar of cents
/// with a mark where it is, its cents; dimmed when it does not sound.
class PitchStringsView extends StatelessWidget {
  /// The strings, low first.
  final List<PitchStringState> strings;

  /// The cents each side of a bar.
  final double range;

  /// The zone in tune, each side.
  final double inTuneCents;

  /// The colors, the theme's by default.
  final PitchColors? colors;

  /// [strings] on bars from -[range] to +[range] cents, in tune within
  /// [inTuneCents], [colors] or the theme's.
  const PitchStringsView({
    super.key,
    required this.strings,
    this.range = 50,
    this.inTuneCents = 5,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    var colors = this.colors ?? PitchColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var (index, string) in strings.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _StringRow(
              key: ValueKey('pitch_string_$index'),
              string: string,
              range: range,
              inTuneCents: inTuneCents,
              colors: colors,
            ),
          ),
      ],
    );
  }
}

class _StringRow extends StatelessWidget {
  final PitchStringState string;
  final double range;
  final double inTuneCents;
  final PitchColors colors;

  const _StringRow({
    super.key,
    required this.string,
    required this.range,
    required this.inTuneCents,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    var cents = string.cents;
    var color = colors.forCents(cents, inTuneCents: inTuneCents);
    return Opacity(
      opacity: cents == null ? 0.45 : 1,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              string.name,
              style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 18),
              painter: _BarPainter(
                cents: cents,
                range: range,
                inTuneCents: inTuneCents,
                color: color,
                colors: colors,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (string.stable && cents != null)
                  Icon(Icons.lock_outline, size: 14, color: color),
                const SizedBox(width: 2),
                Text(
                  cents == null ? '–' : pitchSignedCents(cents, decimals: 0),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double? cents;
  final double range;
  final double inTuneCents;
  final Color color;
  final PitchColors colors;

  _BarPainter({
    required this.cents,
    required this.range,
    required this.inTuneCents,
    required this.color,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double x(double cents) =>
        (cents.clamp(-range, range) + range) / (2 * range) * size.width;
    var middle = size.height / 2;
    canvas
      ..drawLine(
        Offset(0, middle),
        Offset(size.width, middle),
        Paint()
          ..color = colors.line
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      )
      ..drawRect(
        Rect.fromLTRB(x(-inTuneCents), 2, x(inTuneCents), size.height - 2),
        Paint()..color = colors.inTune.withValues(alpha: 0.2),
      )
      ..drawLine(
        Offset(x(0), 0),
        Offset(x(0), size.height),
        Paint()
          ..color = colors.muted
          ..strokeWidth = 1.5,
      );
    var cents = this.cents;
    if (cents != null) {
      canvas.drawCircle(Offset(x(cents), middle), 6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.cents != cents ||
      oldDelegate.range != range ||
      oldDelegate.inTuneCents != inTuneCents ||
      oldDelegate.color != color ||
      oldDelegate.colors != colors;
}
