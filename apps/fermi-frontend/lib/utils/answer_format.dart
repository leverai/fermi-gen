import 'package:fermi_frontend/models/answer_value.dart';

/// Formats an [AnswerValue] to a compact human-readable string.
/// Examples: "234 M km", "12 B", "7"
String formatAnswerValue(AnswerValue value) {
  final String numberPart = value.number.toString();
  final String omPart =
      value.orderOfMagnitude.isEmpty ? '' : value.orderOfMagnitude;
  final String unitPart = value.unit.isEmpty ? '' : ' ${value.unit}';
  return '$numberPart$omPart$unitPart'.trim();
}

/// Formats a number in human-readable scientific notation.
///
/// Uses standard exponential "e" notation for universal font compatibility.
/// The mantissa is limited to 1 decimal place for readability.
///
/// Examples:
/// - 6.21e+30 -> "6.2e30"
/// - 1.5e-8 -> "1.5e-8"
/// - 1.0e+3 -> "1.0e3"
String formatScientificNotation(double value) {
  if (value == 0) return '0';
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';

  // Use Dart's built-in exponential notation
  final String expStr = value.toStringAsExponential(1);

  // Clean up the format: remove '+' from positive exponents for brevity
  // "6.2e+30" -> "6.2e30", "1.5e-8" -> "1.5e-8"
  return expStr.replaceFirst('e+', 'e');
}
