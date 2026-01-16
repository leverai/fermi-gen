import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/utils/om_constants.dart';

void main() {
  group('OM Constants - Multiplier Lookup', () {
    test('should return correct multiplier for each OM', () {
      // ARRANGE & ACT & ASSERT
      // Test each valid OM symbol and its corresponding multiplier
      expect(orderOfMagnitudeMultipliers[''], 1);
      expect(orderOfMagnitudeMultipliers['K'], 1000);
      expect(orderOfMagnitudeMultipliers['M'], 1000000);
      expect(orderOfMagnitudeMultipliers['B'], 1000000000);
      expect(orderOfMagnitudeMultipliers['T'], 1000000000000);
    });

    test('should return 1 for empty OM', () {
      // ARRANGE
      const emptyOm = '';

      // ACT
      final multiplier = orderOfMagnitudeMultipliers[emptyOm] ?? 1;

      // ASSERT
      expect(multiplier, 1);
    });

    test('should return 1 for unknown OM', () {
      // ARRANGE
      const unknownOm = 'X'; // Not a valid OM symbol

      // ACT
      final multiplier = orderOfMagnitudeMultipliers[unknownOm] ?? 1;

      // ASSERT
      expect(multiplier, 1);
    });

    test('should return 1 for null lookup (using null-coalescing pattern)', () {
      // ARRANGE
      const invalidOm = 'invalid';

      // ACT
      // This tests the pattern used in production: map[key] ?? 1
      final multiplier = orderOfMagnitudeMultipliers[invalidOm] ?? 1;

      // ASSERT
      expect(multiplier, 1);
    });

    test('should have consistent multipliers across all valid OMs', () {
      // ARRANGE
      const allValidOms = orderOfMagnitudeSymbols;

      // ACT & ASSERT
      // Verify that all symbols in orderOfMagnitudeSymbols have corresponding multipliers
      for (final om in allValidOms) {
        expect(
          orderOfMagnitudeMultipliers.containsKey(om),
          true,
          reason: 'OM symbol "$om" should have a multiplier defined',
        );
        expect(
          orderOfMagnitudeMultipliers[om],
          isNotNull,
          reason: 'OM symbol "$om" should have a non-null multiplier',
        );
      }
    });

    test('should have multipliers that are powers of 1000', () {
      // ARRANGE & ACT & ASSERT
      // Verify that multipliers follow the pattern: 1000^n
      expect(orderOfMagnitudeMultipliers[''], 1); // 1000^0
      expect(orderOfMagnitudeMultipliers['K'], 1000); // 1000^1
      expect(orderOfMagnitudeMultipliers['M'], 1000000); // 1000^2
      expect(orderOfMagnitudeMultipliers['B'], 1000000000); // 1000^3
      expect(orderOfMagnitudeMultipliers['T'], 1000000000000); // 1000^4
    });
  });
}
