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

/// Unicode superscript digit mapping for exponent display.
const Map<String, String> _superscriptDigits = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
  '-': '⁻',
};

/// Converts an integer to a superscript string using Unicode characters.
/// Examples: 30 -> "³⁰", -5 -> "⁻⁵"
String _toSuperscript(int number) {
  final String digits = number.toString();
  final buffer = StringBuffer();
  for (final char in digits.split('')) {
    buffer.write(_superscriptDigits[char] ?? char);
  }
  return buffer.toString();
}

/// Formats a number in human-readable scientific notation.
///
/// Converts exponential notation like "6.21e+30" to "6.2 × 10³⁰" with
/// Unicode superscript characters for the exponent.
///
/// The mantissa is limited to 1 decimal place for readability.
///
/// Examples:
/// - 6.21e+30 -> "6.2 × 10³⁰"
/// - 1.5e-8 -> "1.5 × 10⁻⁸"
/// - 1.0e+3 -> "1.0 × 10³"
String formatScientificNotation(double value) {
  if (value == 0) return '0';
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';

  // Use Dart's built-in exponential notation and parse it
  // This is reliable for all number ranges
  final String expStr = value.toStringAsExponential(1);

  // Parse the exponential string: "6.2e+30" or "1.5e-8"
  final RegExp expRegex = RegExp(r'^(-?\d+\.?\d*)e([+-]?\d+)$');
  final match = expRegex.firstMatch(expStr);

  if (match == null) {
    // Fallback if parsing fails
    return expStr;
  }

  final String mantissa = match.group(1)!;
  final int exponent = int.parse(match.group(2)!);

  // Convert exponent to superscript
  final String superscriptExponent = _toSuperscript(exponent);

  return '$mantissa × 10$superscriptExponent';
}
