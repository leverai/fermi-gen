import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/models/answer_value.dart';

void main() {
  group('AnswerValue - Equality', () {
    test('should be equal when all fields match', () {
      // ARRANGE
      const value1 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm',
      );
      const value2 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm',
      );

      // ACT & ASSERT
      expect(value1, equals(value2));
      expect(value1 == value2, isTrue);
    });

    test('should not be equal when number differs', () {
      // ARRANGE
      const value1 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm',
      );
      const value2 = AnswerValue(
        number: 43,
        orderOfMagnitude: 'K',
        unit: 'm',
      );

      // ACT & ASSERT
      expect(value1, isNot(equals(value2)));
      expect(value1 == value2, isFalse);
    });

    test('should not be equal when OM differs', () {
      // ARRANGE
      const value1 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm',
      );
      const value2 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'M',
        unit: 'm',
      );

      // ACT & ASSERT
      expect(value1, isNot(equals(value2)));
      expect(value1 == value2, isFalse);
    });

    test('should not be equal when unit differs', () {
      // ARRANGE
      const value1 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm',
      );
      const value2 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'kg',
      );

      // ACT & ASSERT
      expect(value1, isNot(equals(value2)));
      expect(value1 == value2, isFalse);
    });
  });

  group('AnswerValue - Hash Code', () {
    test('should produce same hash for equal values', () {
      // ARRANGE
      const value1 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm',
      );
      const value2 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm',
      );

      // ACT & ASSERT
      expect(value1.hashCode, equals(value2.hashCode));
    });

    test('should produce different hash for different values', () {
      // ARRANGE
      const value1 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm',
      );
      const value2 = AnswerValue(
        number: 43,
        orderOfMagnitude: 'K',
        unit: 'm',
      );
      const value3 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'M',
        unit: 'm',
      );
      const value4 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'kg',
      );

      // ACT & ASSERT
      expect(value1.hashCode, isNot(equals(value2.hashCode)));
      expect(value1.hashCode, isNot(equals(value3.hashCode)));
      expect(value1.hashCode, isNot(equals(value4.hashCode)));
    });
  });

  group('AnswerValue - String Representation', () {
    test('should format toString correctly', () {
      // ARRANGE
      const value1 = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm',
      );
      const value2 = AnswerValue(
        number: 100,
        orderOfMagnitude: '',
        unit: 'kg',
      );
      const value3 = AnswerValue(
        number: 5,
        orderOfMagnitude: 'M',
        unit: '',
      );

      // ACT
      final string1 = value1.toString();
      final string2 = value2.toString();
      final string3 = value3.toString();

      // ASSERT
      expect(string1, equals('AnswerValue(number: 42, om: K, unit: m)'));
      expect(string2, equals('AnswerValue(number: 100, om: , unit: kg)'));
      expect(string3, equals('AnswerValue(number: 5, om: M, unit: )'));
    });
  });
}
