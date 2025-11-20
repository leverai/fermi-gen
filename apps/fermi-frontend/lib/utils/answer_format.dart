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
