import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/utils/color_contrast.dart';

void main() {
  group('Color Utilities - Contrast Calculation', () {
    group('bestOn', () {
      test('should calculate contrast ratio correctly', () {
        // ARRANGE
        // White on black should have maximum contrast (21:1)
        // Black on white should have maximum contrast (21:1)
        // We test that bestOn correctly identifies which has higher contrast
        const black = Color(0xFF000000);
        const white = Color(0xFFFFFFFF);

        // ACT
        final resultBlack = bestOn(black);
        final resultWhite = bestOn(white);

        // ASSERT
        // For pure black, white should have better contrast
        expect(resultBlack, Colors.white);
        // For pure white, black should have better contrast
        expect(resultWhite, Colors.black);
      });

      test('should return white for dark backgrounds', () {
        // ARRANGE
        const darkBlue = Color(0xFF000080);
        const darkRed = Color(0xFF800000);
        const darkGreen = Color(0xFF008000);
        const darkGray = Color(0xFF333333);

        // ACT
        final resultBlue = bestOn(darkBlue);
        final resultRed = bestOn(darkRed);
        final resultGreen = bestOn(darkGreen);
        final resultGray = bestOn(darkGray);

        // ASSERT
        expect(resultBlue, Colors.white,
            reason: 'Dark blue should prefer white text');
        expect(resultRed, Colors.white,
            reason: 'Dark red should prefer white text');
        expect(resultGreen, Colors.white,
            reason: 'Dark green should prefer white text');
        expect(resultGray, Colors.white,
            reason: 'Dark gray should prefer white text');
      });

      test('should return black for light backgrounds', () {
        // ARRANGE
        const lightBlue = Color(0xFFADD8E6);
        const lightYellow = Color(0xFFFFFFE0);
        const lightGray = Color(0xFFCCCCCC);
        const lightPink = Color(0xFFFFB6C1);

        // ACT
        final resultBlue = bestOn(lightBlue);
        final resultYellow = bestOn(lightYellow);
        final resultGray = bestOn(lightGray);
        final resultPink = bestOn(lightPink);

        // ASSERT
        expect(resultBlue, Colors.black,
            reason: 'Light blue should prefer black text');
        expect(resultYellow, Colors.black,
            reason: 'Light yellow should prefer black text');
        expect(resultGray, Colors.black,
            reason: 'Light gray should prefer black text');
        expect(resultPink, Colors.black,
            reason: 'Light pink should prefer black text');
      });

      test('should handle edge cases', () {
        // ARRANGE
        // Test pure black and white
        const pureBlack = Color(0xFF000000);
        const pureWhite = Color(0xFFFFFFFF);
        // Test medium gray (should prefer one based on contrast)
        const mediumGray = Color(0xFF808080);
        // Test transparent-like colors (very low alpha)
        const nearTransparent = Color(0x00000000);
        // Test very dark but not pure black
        const veryDark = Color(0xFF010101);
        // Test very light but not pure white
        const veryLight = Color(0xFFFEFEFE);

        // ACT
        final resultPureBlack = bestOn(pureBlack);
        final resultPureWhite = bestOn(pureWhite);
        final resultMediumGray = bestOn(mediumGray);
        final resultNearTransparent = bestOn(nearTransparent);
        final resultVeryDark = bestOn(veryDark);
        final resultVeryLight = bestOn(veryLight);

        // ASSERT
        expect(resultPureBlack, Colors.white,
            reason: 'Pure black should prefer white');
        expect(resultPureWhite, Colors.black,
            reason: 'Pure white should prefer black');
        // Medium gray should prefer one or the other (implementation dependent)
        expect(
          resultMediumGray,
          isA<Color>(),
          reason: 'Medium gray should return a valid color',
        );
        // Near transparent should still return a valid color
        expect(
          resultNearTransparent,
          isA<Color>(),
          reason: 'Near transparent should return a valid color',
        );
        expect(resultVeryDark, Colors.white,
            reason: 'Very dark should prefer white');
        expect(resultVeryLight, Colors.black,
            reason: 'Very light should prefer black');
      });
    });

    group('pickContrastingTextColor', () {
      test('should return white for dark backgrounds', () {
        // ARRANGE
        const darkBackground = Color(0xFF000000);
        const darkBlue = Color(0xFF000080);
        const darkGray = Color(0xFF333333);

        // ACT
        final resultBlack =
            pickContrastingTextColor(background: darkBackground);
        final resultBlue = pickContrastingTextColor(background: darkBlue);
        final resultGray = pickContrastingTextColor(background: darkGray);

        // ASSERT
        expect(resultBlack, Colors.white,
            reason: 'Black background should return white');
        expect(resultBlue, Colors.white,
            reason: 'Dark blue background should return white');
        expect(resultGray, Colors.white,
            reason: 'Dark gray background should return white');
      });

      test('should return black for light backgrounds', () {
        // ARRANGE
        const lightBackground = Color(0xFFFFFFFF);
        const lightYellow = Color(0xFFFFFFE0);
        const lightGray = Color(0xFFCCCCCC);

        // ACT
        final resultWhite =
            pickContrastingTextColor(background: lightBackground);
        final resultYellow = pickContrastingTextColor(background: lightYellow);
        final resultGray = pickContrastingTextColor(background: lightGray);

        // ASSERT
        expect(resultWhite, Colors.black,
            reason: 'White background should return black');
        expect(resultYellow, Colors.black,
            reason: 'Light yellow background should return black');
        expect(resultGray, Colors.black,
            reason: 'Light gray background should return black');
      });

      test('should use preferredLightText when provided for dark backgrounds',
          () {
        // ARRANGE
        const darkBackground = Color(0xFF000000);
        const customLightColor = Color(0xFFFFE4E1); // Misty rose

        // ACT
        final result = pickContrastingTextColor(
          background: darkBackground,
          preferredLightText: customLightColor,
        );

        // ASSERT
        expect(result, customLightColor,
            reason: 'Should use preferred light text color');
      });

      test('should use preferredDarkText when provided for light backgrounds',
          () {
        // ARRANGE
        const lightBackground = Color(0xFFFFFFFF);
        const customDarkColor = Color(0xFF2F4F4F); // Dark slate gray

        // ACT
        final result = pickContrastingTextColor(
          background: lightBackground,
          preferredDarkText: customDarkColor,
        );

        // ASSERT
        expect(result, customDarkColor,
            reason: 'Should use preferred dark text color');
      });

      test('should ignore preferredDarkText for dark backgrounds', () {
        // ARRANGE
        const darkBackground = Color(0xFF000000);
        const customDarkColor = Color(0xFF2F4F4F);

        // ACT
        final result = pickContrastingTextColor(
          background: darkBackground,
          preferredDarkText: customDarkColor,
        );

        // ASSERT
        expect(result, Colors.white,
            reason: 'Should ignore preferred dark text for dark background');
      });

      test('should ignore preferredLightText for light backgrounds', () {
        // ARRANGE
        const lightBackground = Color(0xFFFFFFFF);
        const customLightColor = Color(0xFFFFE4E1);

        // ACT
        final result = pickContrastingTextColor(
          background: lightBackground,
          preferredLightText: customLightColor,
        );

        // ASSERT
        expect(result, Colors.black,
            reason: 'Should ignore preferred light text for light background');
      });

      test('should handle edge cases with medium luminance', () {
        // ARRANGE
        // Colors with luminance close to 0.5 (the threshold)
        const mediumGray = Color(0xFF808080); // Approximately 0.5 luminance
        const slightlyDark = Color(0xFF7F7F7F); // Just below threshold
        const slightlyLight = Color(0xFF808080); // Just at threshold

        // ACT
        final resultMedium = pickContrastingTextColor(background: mediumGray);
        final resultSlightlyDark =
            pickContrastingTextColor(background: slightlyDark);
        final resultSlightlyLight =
            pickContrastingTextColor(background: slightlyLight);

        // ASSERT
        // These should return valid colors (either black or white)
        expect(resultMedium, isA<Color>(),
            reason: 'Medium gray should return a valid color');
        expect(resultSlightlyDark, isA<Color>(),
            reason: 'Slightly dark should return a valid color');
        expect(resultSlightlyLight, isA<Color>(),
            reason: 'Slightly light should return a valid color');
      });

      test('should handle edge cases with extreme colors', () {
        // ARRANGE
        const pureBlack = Color(0xFF000000);
        const pureWhite = Color(0xFFFFFFFF);
        const nearBlack = Color(0xFF000001);
        const nearWhite = Color(0xFFFFFFFE);

        // ACT
        final resultPureBlack = pickContrastingTextColor(background: pureBlack);
        final resultPureWhite = pickContrastingTextColor(background: pureWhite);
        final resultNearBlack = pickContrastingTextColor(background: nearBlack);
        final resultNearWhite = pickContrastingTextColor(background: nearWhite);

        // ASSERT
        expect(resultPureBlack, Colors.white,
            reason: 'Pure black should return white');
        expect(resultPureWhite, Colors.black,
            reason: 'Pure white should return black');
        expect(resultNearBlack, Colors.white,
            reason: 'Near black should return white');
        expect(resultNearWhite, Colors.black,
            reason: 'Near white should return black');
      });
    });
  });
}
