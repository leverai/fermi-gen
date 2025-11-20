import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/theme/colormap.dart';

void main() {
  group('normalizeToUnitInterval', () {
    test('should normalize value within range to [0,1]', () {
      // ARRANGE
      const value = 50.0;
      const min = 0.0;
      const max = 100.0;

      // ACT
      final result = normalizeToUnitInterval(value, min, max);

      // ASSERT
      expect(result, 0.5);
    });

    test('should return 0.0 when value equals min', () {
      // ARRANGE
      const value = 10.0;
      const min = 10.0;
      const max = 20.0;

      // ACT
      final result = normalizeToUnitInterval(value, min, max);

      // ASSERT
      expect(result, 0.0);
    });

    test('should return 1.0 when value equals max', () {
      // ARRANGE
      const value = 20.0;
      const min = 10.0;
      const max = 20.0;

      // ACT
      final result = normalizeToUnitInterval(value, min, max);

      // ASSERT
      expect(result, 1.0);
    });

    test('should clamp values below min to 0.0', () {
      // ARRANGE
      const value = -10.0;
      const min = 0.0;
      const max = 100.0;

      // ACT
      final result = normalizeToUnitInterval(value, min, max);

      // ASSERT
      expect(result, 0.0);
    });

    test('should clamp values above max to 1.0', () {
      // ARRANGE
      const value = 150.0;
      const min = 0.0;
      const max = 100.0;

      // ACT
      final result = normalizeToUnitInterval(value, min, max);

      // ASSERT
      expect(result, 1.0);
    });

    test('should return 0.0 when min equals max', () {
      // ARRANGE
      const value = 5.0;
      const min = 10.0;
      const max = 10.0;

      // ACT
      final result = normalizeToUnitInterval(value, min, max);

      // ASSERT
      expect(result, 0.0);
    });

    test('should handle negative ranges', () {
      // ARRANGE
      const value = -5.0;
      const min = -10.0;
      const max = 0.0;

      // ACT
      final result = normalizeToUnitInterval(value, min, max);

      // ASSERT
      expect(result, 0.5);
    });

    test('should handle fractional values correctly', () {
      // ARRANGE
      const value = 25.5;
      const min = 0.0;
      const max = 100.0;

      // ACT
      final result = normalizeToUnitInterval(value, min, max);

      // ASSERT
      expect(result, 0.255);
    });
  });
}
