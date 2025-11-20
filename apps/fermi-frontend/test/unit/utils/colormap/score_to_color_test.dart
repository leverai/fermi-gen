import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/colormap.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

void main() {
  group('scoreToColor', () {
    final defaultTheme = AppTheme.defaultTheme();
    final dangerColor = defaultTheme.danger;
    final successColor = defaultTheme.success;

    test('should map low scores to danger color', () {
      // ARRANGE
      const lowScore = 0;

      // ACT
      final color = scoreToColor(lowScore);

      // ASSERT
      expect(color, dangerColor);
    });

    test('should map high scores to success color', () {
      // ARRANGE
      const highScore = 6000; // Default max

      // ACT
      final color = scoreToColor(highScore);

      // ASSERT
      expect(color, successColor);
    });

    test('should interpolate between colors for intermediate scores', () {
      // ARRANGE
      const midScore = 3000; // Half of default max

      // ACT
      final color = scoreToColor(midScore);

      // ASSERT
      // At 50% of range, we should get a color halfway between danger and success
      expect(color, isNot(equals(dangerColor)));
      expect(color, isNot(equals(successColor)));
      final expectedColor = Color.lerp(dangerColor, successColor, 0.5);
      expect(color, expectedColor);
    });

    test('should handle edge score at minimum', () {
      // ARRANGE
      const edgeScore = 0;

      // ACT
      final color = scoreToColor(edgeScore);

      // ASSERT
      expect(color, dangerColor);
    });

    test('should handle edge score at maximum', () {
      // ARRANGE
      const edgeScore = 6000; // Default max

      // ACT
      final color = scoreToColor(edgeScore);

      // ASSERT
      expect(color, successColor);
    });

    test('should clamp values below minimum to danger color', () {
      // ARRANGE
      const belowMinScore = -100;

      // ACT
      final color = scoreToColor(belowMinScore);

      // ASSERT
      expect(color, dangerColor);
    });

    test('should clamp values above maximum to success color', () {
      // ARRANGE
      const aboveMaxScore = 10000;

      // ACT
      final color = scoreToColor(aboveMaxScore);

      // ASSERT
      expect(color, successColor);
    });

    test('should accept custom min and max values', () {
      // ARRANGE
      const score = 50;
      const customMin = 0;
      const customMax = 100;

      // ACT
      final color = scoreToColor(score, min: customMin, max: customMax);

      // ASSERT
      // At 50 out of 100, should be halfway between danger and success
      final expectedColor = Color.lerp(dangerColor, successColor, 0.5);
      expect(color, expectedColor);
    });

    test('should handle custom range with different min', () {
      // ARRANGE
      const score = 150;
      const customMin = 100;
      const customMax = 200;

      // ACT
      final color = scoreToColor(score, min: customMin, max: customMax);

      // ASSERT
      // At 150 out of 100-200 range, should be halfway (t=0.5)
      final expectedColor = Color.lerp(dangerColor, successColor, 0.5);
      expect(color, expectedColor);
    });

    test('should accept custom theme', () {
      // ARRANGE
      const score = 3000;
      final customTheme = AppTheme.defaultTheme().copyWith(
        danger: Colors.blue,
        success: Colors.yellow,
      );

      // ACT
      final color = scoreToColor(score, theme: customTheme);

      // ASSERT
      final expectedColor = Color.lerp(Colors.blue, Colors.yellow, 0.5);
      expect(color, expectedColor);
    });

    test('should handle integer score values', () {
      // ARRANGE
      const intScore = 4500; // 75% of default max

      // ACT
      final color = scoreToColor(intScore);

      // ASSERT
      final expectedColor = Color.lerp(dangerColor, successColor, 0.75);
      expect(color, expectedColor);
    });
  });
}
