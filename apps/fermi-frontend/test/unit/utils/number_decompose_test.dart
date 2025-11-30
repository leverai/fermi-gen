import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/utils/number_decompose.dart';
import 'package:fermi_frontend/models/answer_value.dart';

void main() {
  group('decomposeNumber', () {
    test('decomposes regular numbers correctly', () {
      // 1234 -> 1K
      expect(
        decomposeNumber(1234, 'km'),
        const AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'km'),
      );

      // 5678000 -> 6M (rounded)
      expect(
        decomposeNumber(5678000, 'm'),
        const AnswerValue(number: 6, orderOfMagnitude: 'M', unit: 'm'),
      );

      // 123 -> 123 (no OM)
      expect(
        decomposeNumber(123, 'kg'),
        const AnswerValue(number: 123, orderOfMagnitude: '', unit: 'kg'),
      );
    });

    test('caps values below 1 to 1', () {
      expect(
        decomposeNumber(0.5, 'mm'),
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'mm'),
      );

      expect(
        decomposeNumber(0.001, 'g'),
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'g'),
      );
    });

    test('caps values above 999Qa to 999Qa', () {
      // 1e18 -> 999Qa (capped)
      expect(
        decomposeNumber(1e18, 'km'),
        const AnswerValue(number: 999, orderOfMagnitude: 'Qa', unit: 'km'),
      );

      // 999e15 -> 999Qa (at limit)
      expect(
        decomposeNumber(999e15, 'm'),
        const AnswerValue(number: 999, orderOfMagnitude: 'Qa', unit: 'm'),
      );
    });

    test('handles edge cases', () {
      // Zero
      expect(
        decomposeNumber(0, 'kg'),
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'kg'),
      );

      // Negative (treated as invalid, returns default)
      expect(
        decomposeNumber(-100, 'km'),
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'km'),
      );

      // Exactly 1
      expect(
        decomposeNumber(1, 'm'),
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm'),
      );

      // Exactly 999
      expect(
        decomposeNumber(999, 'kg'),
        const AnswerValue(number: 999, orderOfMagnitude: '', unit: 'kg'),
      );

      // Exactly 1000 (should be 1K)
      expect(
        decomposeNumber(1000, 'km'),
        const AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'km'),
      );
    });

    test('handles all order of magnitude ranges', () {
      // K range
      expect(
        decomposeNumber(500000, 'km'),
        const AnswerValue(number: 500, orderOfMagnitude: 'K', unit: 'km'),
      );

      // M range
      expect(
        decomposeNumber(250000000, 'm'),
        const AnswerValue(number: 250, orderOfMagnitude: 'M', unit: 'm'),
      );

      // B range
      expect(
        decomposeNumber(750000000000, 'kg'),
        const AnswerValue(number: 750, orderOfMagnitude: 'B', unit: 'kg'),
      );

      // T range
      expect(
        decomposeNumber(100000000000000, 'km'),
        const AnswerValue(number: 100, orderOfMagnitude: 'T', unit: 'km'),
      );

      // Qa range
      expect(
        decomposeNumber(500000000000000000, 'm'),
        const AnswerValue(number: 500, orderOfMagnitude: 'Qa', unit: 'm'),
      );
    });
  });
}
