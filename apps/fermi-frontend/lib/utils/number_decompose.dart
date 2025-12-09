import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/om_constants.dart';

/// Decomposes an absolute number into (number, orderOfMagnitude) format.
///
/// The number component will be in the range [1, 999] and the order of magnitude
/// will be one of: '', 'K', 'M', 'B', 'T'.
///
/// If the value is too large (>999T), it caps at 999T.
/// If the value is too small (<1), it caps at 1 with empty OM.
///
/// Examples:
/// - 1234 -> (number: 1, om: 'K')
/// - 0.5 -> (number: 1, om: '') [capped]
/// - 1e18 -> (number: 999, om: 'T') [capped]
AnswerValue decomposeNumber(double absoluteValue, String unit) {
  // Handle edge cases
  if (absoluteValue <= 0 || absoluteValue.isNaN || absoluteValue.isInfinite) {
    return AnswerValue(
        number: 1, orderOfMagnitude: '', unit: unit, rawValue: absoluteValue);
  }

  // Cap at minimum displayable value (1)
  if (absoluteValue < 1) {
    return AnswerValue(
        number: 1, orderOfMagnitude: '', unit: unit, rawValue: absoluteValue);
  }

  // Cap at maximum displayable value (999T = 999e12)
  const double maxDisplayable = 999e12;
  if (absoluteValue > maxDisplayable) {
    return AnswerValue(
        number: 999,
        orderOfMagnitude: 'T',
        unit: unit,
        rawValue: absoluteValue);
  }

  // Find the appropriate order of magnitude
  // Start from the largest OM and work down
  for (int i = orderOfMagnitudeSymbols.length - 1; i >= 0; i--) {
    final String om = orderOfMagnitudeSymbols[i];
    final int multiplier = orderOfMagnitudeMultipliers[om]!;
    final double quotient = absoluteValue / multiplier;

    // If quotient is >= 1 and < 1000, we found the right OM
    if (quotient >= 1 && quotient < 1000) {
      final int number = quotient.round().clamp(1, 999);
      return AnswerValue(
          number: number,
          orderOfMagnitude: om,
          unit: unit,
          rawValue: absoluteValue);
    }
  }

  // Fallback (should not reach here due to capping logic above)
  return AnswerValue(
      number: 1, orderOfMagnitude: '', unit: unit, rawValue: absoluteValue);
}
