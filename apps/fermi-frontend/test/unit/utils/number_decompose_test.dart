import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/utils/number_decompose.dart';
import 'package:fermi_frontend/models/answer_value.dart';

void main() {
  group('decomposeNumber', () {
    test('decomposes regular numbers correctly', () {
      // 1234 -> 1K
      expect(
        decomposeNumber(1234, 'km'),
        AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'km', rawValue: 1234.0),
      );

      // 5678000 -> 6M (rounded)
      expect(
        decomposeNumber(5678000, 'm'),
        AnswerValue(number: 6, orderOfMagnitude: 'M', unit: 'm', rawValue: 5678000.0),
      );

      // 123 -> 123 (no OM)
      expect(
        decomposeNumber(123, 'kg'),
        AnswerValue(number: 123, orderOfMagnitude: '', unit: 'kg', rawValue: 123.0),
      );
    });

    test('caps values below 1 to 1', () {
      expect(
        decomposeNumber(0.5, 'mm'),
        AnswerValue(number: 1, orderOfMagnitude: '', unit: 'mm', rawValue: 0.5),
      );

      expect(
        decomposeNumber(0.001, 'g'),
        AnswerValue(number: 1, orderOfMagnitude: '', unit: 'g', rawValue: 0.001),
      );
    });

    test('caps values above 999Qa to 999Qa', () {
      // 1e18 -> 999Qa (capped)
      expect(
        decomposeNumber(1e18, 'km'),
        AnswerValue(number: 999, orderOfMagnitude: 'Qa', unit: 'km', rawValue: 1e18),
      );

      // 999e15 -> 999Qa (at limit)
      expect(
        decomposeNumber(999e15, 'm'),
        AnswerValue(number: 999, orderOfMagnitude: 'Qa', unit: 'm', rawValue: 999e15),
      );
    });

    test('handles edge cases', () {
      // Zero
      expect(
        decomposeNumber(0, 'kg'),
        AnswerValue(number: 1, orderOfMagnitude: '', unit: 'kg', rawValue: 0.0),
      );

      // Negative (treated as invalid, returns default)
      expect(
        decomposeNumber(-100, 'km'),
        AnswerValue(number: 1, orderOfMagnitude: '', unit: 'km', rawValue: -100.0),
      );

      // Exactly 1
      expect(
        decomposeNumber(1, 'm'),
        AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm', rawValue: 1.0),
      );

      // Exactly 999
      expect(
        decomposeNumber(999, 'kg'),
        AnswerValue(number: 999, orderOfMagnitude: '', unit: 'kg', rawValue: 999.0),
      );

      // Exactly 1000 (should be 1K)
      expect(
        decomposeNumber(1000, 'km'),
        AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'km', rawValue: 1000.0),
      );
    });

    test('handles all order of magnitude ranges', () {
      // K range
      expect(
        decomposeNumber(500000, 'km'),
        AnswerValue(number: 500, orderOfMagnitude: 'K', unit: 'km', rawValue: 500000.0),
      );

      // M range
      expect(
        decomposeNumber(250000000, 'm'),
        AnswerValue(number: 250, orderOfMagnitude: 'M', unit: 'm', rawValue: 250000000.0),
      );

      // B range
      expect(
        decomposeNumber(750000000000, 'kg'),
        AnswerValue(number: 750, orderOfMagnitude: 'B', unit: 'kg', rawValue: 750000000000.0),
      );

      // T range
      expect(
        decomposeNumber(100000000000000, 'km'),
        AnswerValue(number: 100, orderOfMagnitude: 'T', unit: 'km', rawValue: 100000000000000.0),
      );

      // Qa range
      expect(
        decomposeNumber(500000000000000000, 'm'),
        AnswerValue(number: 500, orderOfMagnitude: 'Qa', unit: 'm', rawValue: 500000000000000000.0),
      );
    });
  });
}
