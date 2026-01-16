import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/utils/number_decompose.dart';
import 'package:fermi_frontend/models/answer_value.dart';

void main() {
  group('composeNumber', () {
    test('composes numbers without order of magnitude', () {
      expect(
        composeNumber(const AnswerValue(
            number: 1, orderOfMagnitude: '', unit: 'km')),
        1.0,
      );

      expect(
        composeNumber(const AnswerValue(
            number: 123, orderOfMagnitude: '', unit: 'kg')),
        123.0,
      );

      expect(
        composeNumber(const AnswerValue(
            number: 999, orderOfMagnitude: '', unit: 'm')),
        999.0,
      );
    });

    test('composes numbers with K (thousand)', () {
      expect(
        composeNumber(const AnswerValue(
            number: 1, orderOfMagnitude: 'K', unit: 'km')),
        1000.0,
      );

      expect(
        composeNumber(const AnswerValue(
            number: 500, orderOfMagnitude: 'K', unit: 'm')),
        500000.0,
      );
    });

    test('composes numbers with M (million)', () {
      expect(
        composeNumber(const AnswerValue(
            number: 1, orderOfMagnitude: 'M', unit: 'ton')),
        1000000.0,
      );

      expect(
        composeNumber(const AnswerValue(
            number: 400, orderOfMagnitude: 'M', unit: 'ton')),
        400000000.0,
      );
    });

    test('composes numbers with B (billion)', () {
      expect(
        composeNumber(const AnswerValue(
            number: 1, orderOfMagnitude: 'B', unit: 'km')),
        1000000000.0,
      );

      expect(
        composeNumber(const AnswerValue(
            number: 750, orderOfMagnitude: 'B', unit: 'kg')),
        750000000000.0,
      );
    });

    test('composes numbers with T (trillion)', () {
      expect(
        composeNumber(const AnswerValue(
            number: 1, orderOfMagnitude: 'T', unit: 'km')),
        1000000000000.0,
      );

      expect(
        composeNumber(const AnswerValue(
            number: 100, orderOfMagnitude: 'T', unit: 'm')),
        100000000000000.0,
      );
    });

    test('composeNumber is inverse of decomposeNumber for exact values', () {
      // Test round-trip for values that don't lose precision during decomposition
      // (values that are exact multiples of their order of magnitude)
      const testValues = [
        123.0, // No OM
        1000.0, // 1K
        500000.0, // 500K
        6000000.0, // 6M (decomposeNumber rounds 5678000 to this)
        250000000.0, // 250M
        750000000000.0, // 750B
        100000000000000.0, // 100T
      ];

      for (final value in testValues) {
        final decomposed = decomposeNumber(value, 'unit');
        final composed = composeNumber(decomposed);
        // These should be exact matches since they're already rounded
        expect(composed, equals(value));
      }
    });
  });

  group('decomposeNumber', () {
    test('decomposes regular numbers correctly', () {
      // 1234 -> 1K
      expect(
        decomposeNumber(1234, 'km'),
        const AnswerValue(
            number: 1, orderOfMagnitude: 'K', unit: 'km', rawValue: 1234.0),
      );

      // 5678000 -> 6M (rounded)
      expect(
        decomposeNumber(5678000, 'm'),
        const AnswerValue(
            number: 6, orderOfMagnitude: 'M', unit: 'm', rawValue: 5678000.0),
      );

      // 123 -> 123 (no OM)
      expect(
        decomposeNumber(123, 'kg'),
        const AnswerValue(
            number: 123, orderOfMagnitude: '', unit: 'kg', rawValue: 123.0),
      );
    });

    test('caps values below 1 to 1', () {
      expect(
        decomposeNumber(0.5, 'mm'),
        const AnswerValue(
            number: 1, orderOfMagnitude: '', unit: 'mm', rawValue: 0.5),
      );

      expect(
        decomposeNumber(0.001, 'g'),
        const AnswerValue(
            number: 1, orderOfMagnitude: '', unit: 'g', rawValue: 0.001),
      );
    });

    test('caps values above 999T to 999T', () {
      // 1e18 -> 999T (capped)
      expect(
        decomposeNumber(1e18, 'km'),
        const AnswerValue(
            number: 999, orderOfMagnitude: 'T', unit: 'km', rawValue: 1e18),
      );

      // 999e12 -> 999T (at limit)
      expect(
        decomposeNumber(999e12, 'm'),
        const AnswerValue(
            number: 999, orderOfMagnitude: 'T', unit: 'm', rawValue: 999e12),
      );
    });

    test('handles edge cases', () {
      // Zero
      expect(
        decomposeNumber(0, 'kg'),
        const AnswerValue(
            number: 1, orderOfMagnitude: '', unit: 'kg', rawValue: 0.0),
      );

      // Negative (treated as invalid, returns default)
      expect(
        decomposeNumber(-100, 'km'),
        const AnswerValue(
            number: 1, orderOfMagnitude: '', unit: 'km', rawValue: -100.0),
      );

      // Exactly 1
      expect(
        decomposeNumber(1, 'm'),
        const AnswerValue(
            number: 1, orderOfMagnitude: '', unit: 'm', rawValue: 1.0),
      );

      // Exactly 999
      expect(
        decomposeNumber(999, 'kg'),
        const AnswerValue(
            number: 999, orderOfMagnitude: '', unit: 'kg', rawValue: 999.0),
      );

      // Exactly 1000 (should be 1K)
      expect(
        decomposeNumber(1000, 'km'),
        const AnswerValue(
            number: 1, orderOfMagnitude: 'K', unit: 'km', rawValue: 1000.0),
      );
    });

    test('handles all order of magnitude ranges', () {
      // K range
      expect(
        decomposeNumber(500000, 'km'),
        const AnswerValue(
            number: 500, orderOfMagnitude: 'K', unit: 'km', rawValue: 500000.0),
      );

      // M range
      expect(
        decomposeNumber(250000000, 'm'),
        const AnswerValue(
            number: 250,
            orderOfMagnitude: 'M',
            unit: 'm',
            rawValue: 250000000.0),
      );

      // B range
      expect(
        decomposeNumber(750000000000, 'kg'),
        const AnswerValue(
            number: 750,
            orderOfMagnitude: 'B',
            unit: 'kg',
            rawValue: 750000000000.0),
      );

      // T range
      expect(
        decomposeNumber(100000000000000, 'km'),
        const AnswerValue(
            number: 100,
            orderOfMagnitude: 'T',
            unit: 'km',
            rawValue: 100000000000000.0),
      );
    });
  });
}
