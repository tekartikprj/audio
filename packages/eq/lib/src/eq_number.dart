/// [value] as the shortest text that reads back the same double, without
/// a trailing `.0` (`105`, `0.7`, `-6.25`, `0` for -0): the form of the
/// numbers the PipeWire conf and controls get.
String eqFormatNumber(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  return value.toString();
}
