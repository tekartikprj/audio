import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'colors.dart';

/// A needle from -[range] to +[range] cents with the zone in tune in the
/// middle ([inTuneCents] each side); no needle when [cents] is null.
class PitchGauge extends StatelessWidget {
  /// The cents shown, null when nothing is heard.
  final double? cents;

  /// The cents each side of the gauge.
  final double range;

  /// The zone in tune, each side.
  final double inTuneCents;

  /// The height (the width follows the parent).
  final double height;

  /// The colors, the theme's by default.
  final PitchColors? colors;

  /// A gauge showing [cents] (null: nothing heard) from -[range] to
  /// +[range], in tune within [inTuneCents], [height] high, [colors] or
  /// the theme's.
  const PitchGauge({
    super.key,
    required this.cents,
    this.range = 50,
    this.inTuneCents = 5,
    this.height = 96,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    var colors = this.colors ?? PitchColors.of(context);
    var cents = this.cents;
    return Semantics(
      label: cents == null ? null : '${cents.round()} cents',
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _GaugePainter(
          cents: cents,
          range: range,
          inTuneCents: inTuneCents,
          colors: colors,
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double? cents;
  final double range;
  final double inTuneCents;
  final PitchColors colors;

  _GaugePainter({
    required this.cents,
    required this.range,
    required this.inTuneCents,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var center = Offset(size.width / 2, size.height - 8);
    var radius = math.min(size.width / 2 - 8, size.height - 14);
    double angle(double cents) => -math.pi / 2 + cents / range * 0.9;
    var rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      angle(-range),
      angle(range) - angle(-range),
      false,
      Paint()
        ..color = colors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      rect,
      angle(-inTuneCents),
      angle(inTuneCents) - angle(-inTuneCents),
      false,
      Paint()
        ..color = colors.inTune
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    var step = range / 5;
    for (var i = -5; i <= 5; i++) {
      var a = angle(i * step);
      var direction = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + direction * (radius - 10),
        center + direction * (radius - 18),
        Paint()
          ..color = colors.muted
          ..strokeWidth = i == 0 ? 2.5 : 1,
      );
    }
    var cents = this.cents;
    var color = colors.forCents(cents, inTuneCents: inTuneCents);
    if (cents != null) {
      var a = angle(cents.clamp(-range, range));
      canvas.drawLine(
        center,
        center + Offset(math.cos(a), math.sin(a)) * (radius - 4),
        Paint()
          ..color = color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(center, 6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.cents != cents ||
      oldDelegate.range != range ||
      oldDelegate.inTuneCents != inTuneCents ||
      oldDelegate.colors != colors;
}
