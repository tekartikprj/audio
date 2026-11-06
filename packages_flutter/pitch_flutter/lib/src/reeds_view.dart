import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tekartik_pitch/pitch.dart';

import 'colors.dart';

/// The cents with a sign and one decimal (a minus sign, `0.0` without a
/// sign).
String pitchSignedCents(double cents, {int decimals = 1}) {
  var text = cents.abs().toStringAsFixed(decimals);
  if (double.parse(text) == 0) {
    return text;
  }
  return '${cents < 0 ? '−' : '+'}$text';
}

/// The reeds of a held note on a line of cents: a dot per reed (larger
/// when louder, faint when weakly supported) with its cents above, the
/// beats per second of each pair under it. The line widens when a reed is
/// far off.
class PitchReedsView extends StatelessWidget {
  /// The reeds.
  final PitchReeds reeds;

  /// The label of a number of beats per second (`5.0 beats/s`).
  final String Function(double beats) beatsLabel;

  /// The label of the cents of a reed for accessibility (`+19.6 cents`).
  final String Function(double cents) centsLabel;

  /// The height.
  final double height;

  /// The colors, the theme's by default.
  final PitchColors? colors;

  /// [reeds] on a line [height] high, their beats labeled by [beatsLabel]
  /// (their cents by [centsLabel] for accessibility), [colors] or the
  /// theme's.
  const PitchReedsView({
    super.key,
    required this.reeds,
    this.beatsLabel = pitchBeatsLabel,
    this.centsLabel = pitchCentsLabel,
    this.height = 92,
    this.colors,
  });

  /// The default label of the cents of a reed.
  static String pitchCentsLabel(double cents) =>
      '${pitchSignedCents(cents)} cents';

  /// The default label of a number of beats per second.
  static String pitchBeatsLabel(double beats) =>
      '${beats.toStringAsFixed(1)} beats/s';

  @override
  Widget build(BuildContext context) {
    var colors = this.colors ?? PitchColors.of(context);
    return Semantics(
      label: [
        for (var reed in reeds.reeds) centsLabel(reed.cents),
        ...reeds.beats.map(beatsLabel),
      ].join(', '),
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _ReedsPainter(
          reeds: reeds,
          beatsLabel: beatsLabel,
          colors: colors,
          fontFamily: pitchFontFamily(context),
        ),
      ),
    );
  }
}

class _ReedsPainter extends CustomPainter {
  final PitchReeds reeds;
  final String Function(double beats) beatsLabel;
  final PitchColors colors;
  final String? fontFamily;

  _ReedsPainter({
    required this.reeds,
    required this.beatsLabel,
    required this.colors,
    required this.fontFamily,
  });

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
    double maxX,
  ) {
    var painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(fontFamily: fontFamily),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var x = (center.dx - painter.width / 2)
        .clamp(0.0, math.max(0.0, maxX - painter.width))
        .toDouble();
    painter.paint(canvas, Offset(x, center.dy - painter.height / 2));
    painter.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    var far = reeds.reeds.fold(
      0.0,
      (max, reed) => math.max(max, reed.cents.abs()),
    );
    var range = math
        .max(30.0, ((far + 8) / 10).ceil() * 10.0)
        .clamp(30.0, 100.0);
    const margin = 18.0;
    double x(double cents) =>
        margin +
        (cents.clamp(-range, range) + range) /
            (2 * range) *
            (size.width - 2 * margin);
    var axis = size.height * 0.48;
    canvas.drawRect(
      Rect.fromLTRB(x(-5), axis - 6, x(5), axis + 6),
      Paint()..color = colors.inTune.withValues(alpha: 0.16),
    );
    canvas.drawLine(
      Offset(x(-range), axis),
      Offset(x(range), axis),
      Paint()
        ..color = colors.line
        ..strokeWidth = 2,
    );
    for (var mark = -range; mark <= range; mark += 10) {
      canvas.drawLine(
        Offset(x(mark), axis - (mark == 0 ? 8 : 4)),
        Offset(x(mark), axis + (mark == 0 ? 8 : 4)),
        Paint()
          ..color = mark == 0 ? colors.muted : colors.line
          ..strokeWidth = mark == 0 ? 2 : 1,
      );
    }
    var small = TextStyle(color: colors.muted, fontSize: 11);
    for (var end in [-range, range]) {
      _text(
        canvas,
        pitchSignedCents(end, decimals: 0),
        Offset(x(end), axis + 16),
        small,
        size.width,
      );
    }
    var beats = reeds.beats;
    for (var i = 0; i < beats.length; i++) {
      var from = x(reeds.reeds[i].cents);
      var to = x(reeds.reeds[i + 1].cents);
      var y = axis + 20;
      var paint = Paint()..color = colors.muted;
      canvas
        ..drawLine(Offset(from, y - 4), Offset(from, y), paint)
        ..drawLine(Offset(from, y), Offset(to, y), paint)
        ..drawLine(Offset(to, y - 4), Offset(to, y), paint);
      _text(
        canvas,
        beatsLabel(beats[i]),
        Offset((from + to) / 2, y + 12),
        TextStyle(color: colors.ink, fontSize: 12, fontWeight: FontWeight.w600),
        size.width,
      );
    }
    for (var reed in reeds.reeds) {
      var color = reed.cents.abs() <= 5 ? colors.inTune : colors.accent;
      var center = Offset(x(reed.cents), axis);
      canvas.drawCircle(
        center,
        5 + 4 * reed.level.clamp(0.0, 1.0),
        Paint()
          ..color = color.withValues(
            alpha: 0.4 + 0.6 * reed.support.clamp(0.0, 1.0),
          ),
      );
      _text(
        canvas,
        pitchSignedCents(reed.cents),
        Offset(center.dx, axis - 22),
        TextStyle(color: colors.ink, fontSize: 13, fontWeight: FontWeight.w700),
        size.width,
      );
    }
  }

  @override
  bool shouldRepaint(_ReedsPainter oldDelegate) =>
      oldDelegate.reeds != reeds ||
      oldDelegate.colors != colors ||
      oldDelegate.fontFamily != fontFamily;
}
