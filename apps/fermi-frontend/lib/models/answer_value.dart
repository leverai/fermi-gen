/// Complete answer value (number, order of magnitude, unit)
class AnswerValue {
  final int number; // 1..999
  final String orderOfMagnitude; // '', K, M, B, T, Qa
  final String unit; // unit abbreviation

  const AnswerValue({
    required this.number,
    required this.orderOfMagnitude,
    required this.unit,
  });

  @override
  String toString() =>
      'AnswerValue(number: $number, om: $orderOfMagnitude, unit: $unit)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswerValue &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          orderOfMagnitude == other.orderOfMagnitude &&
          unit == other.unit;

  @override
  int get hashCode => Object.hash(number, orderOfMagnitude, unit);
}
