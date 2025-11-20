import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/colormap.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

void main() {
  group('percentileToColor', () {
    final defaultTheme = AppTheme.defaultTheme();
    final dangerColor = defaultTheme.danger;
    final successColor = defaultTheme.success;

    test('should map low scores to danger color', () {
      // ARRANGE
      const lowPercentile = 0.0;

      // ACT
      final color = percentileToColor(lowPercentile);

      // ASSERT
      expect(color, dangerColor);
    });

    test('should map high scores to success color', () {
      // ARRANGE
      const highPercentile = 100.0;

      // ACT
      final color = percentileToColor(highPercentile);

      // ASSERT
      expect(color, successColor);
    });

    test('should interpolate between colors for intermediate scores', () {
      // ARRANGE
      const midPercentile = 50.0;

      // ACT
      final color = percentileToColor(midPercentile);

      // ASSERT
      // At 50%, we should get a color halfway between danger and success
      // Verify it's not equal to either endpoint
      expect(color, isNot(equals(dangerColor)));
      expect(color, isNot(equals(successColor)));
      // Verify it's a valid interpolation (using Color.lerp logic)
      final expectedColor = Color.lerp(dangerColor, successColor, 0.5);
      expect(color, expectedColor);
    });

    test('should handle edge score 0%', () {
      // ARRANGE
      const edgePercentile = 0;

      // ACT
      final color = percentileToColor(edgePercentile);

      // ASSERT
      expect(color, dangerColor);
    });

    test('should handle edge score 100%', () {
      // ARRANGE
      const edgePercentile = 100;

      // ACT
      final color = percentileToColor(edgePercentile);

      // ASSERT
      expect(color, successColor);
    });

    test('should clamp values below 0 to danger color', () {
      // ARRANGE
      const negativePercentile = -10.0;

      // ACT
      final color = percentileToColor(negativePercentile);

      // ASSERT
      expect(color, dangerColor);
    });

    test('should clamp values above 100 to success color', () {
      // ARRANGE
      const overPercentile = 150.0;

      // ACT
      final color = percentileToColor(overPercentile);

      // ASSERT
      expect(color, successColor);
    });

    test('should accept custom theme', () {
      // ARRANGE
      const percentile = 50.0;
      final customTheme = AppTheme.defaultTheme().copyWith(
        danger: Colors.red,
        success: Colors.green,
      );

      // ACT
      final color = percentileToColor(percentile, theme: customTheme);

      // ASSERT
      final expectedColor = Color.lerp(Colors.red, Colors.green, 0.5);
      expect(color, expectedColor);
    });

    test('should handle integer percentile values', () {
      // ARRANGE
      const intPercentile = 75;

      // ACT
      final color = percentileToColor(intPercentile);

      // ASSERT
      // At 75%, should be closer to success than danger
      final expectedColor = Color.lerp(dangerColor, successColor, 0.75);
      expect(color, expectedColor);
    });
  });
}
