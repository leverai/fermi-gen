/// Complete answer value (number, order of magnitude, unit)
class AnswerValue {
  final int number; // 1..999
  final String orderOfMagnitude; // '', K, M, B, T, Qa
  final String unit; // unit abbreviation
  final double?
      rawValue; // Original raw value (if available) for scientific notation display

  const AnswerValue({
    required this.number,
    required this.orderOfMagnitude,
    required this.unit,
    this.rawValue,
  });

  @override
  String toString() =>
      'AnswerValue(number: $number, om: $orderOfMagnitude, unit: $unit, rawValue: $rawValue)';

  /// Creates a copy of this AnswerValue with the given fields replaced.
  AnswerValue copyWith({
    int? number,
    String? orderOfMagnitude,
    String? unit,
    double? rawValue,
  }) {
    return AnswerValue(
      number: number ?? this.number,
      orderOfMagnitude: orderOfMagnitude ?? this.orderOfMagnitude,
      unit: unit ?? this.unit,
      rawValue: rawValue ?? this.rawValue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswerValue &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          orderOfMagnitude == other.orderOfMagnitude &&
          unit == other.unit &&
          rawValue == other.rawValue;

  @override
  int get hashCode => Object.hash(number, orderOfMagnitude, unit, rawValue);
}
