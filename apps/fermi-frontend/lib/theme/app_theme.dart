import 'package:flutter/material.dart';

/// Global app theme that provides consistent colors across the application.
/// These colors are used for backgrounds, text, borders, and semantic colors
/// throughout the app.
///
/// Colors are defined using HSL (Hue, Saturation, Lightness) values and converted
/// to RGB Color objects using Flutter's HSLColor class.
@immutable
class AppTheme extends ThemeExtension<AppTheme> {
  // Background colors (dark theme)
  final Color bgDark;
  final Color bg;
  final Color bgLight;

  // Text colors
  final Color text;
  final Color textMuted;

  // UI element colors
  final Color highlight;
  final Color border;
  final Color borderMuted;

  // Brand colors
  final Color primary;
  final Color primaryMuted;
  final Color secondary;
  final Color secondaryMuted;

  // Semantic colors
  final Color danger;
  final Color warning;
  final Color success;
  final Color info;

  const AppTheme({
    required this.bgDark,
    required this.bg,
    required this.bgLight,
    required this.text,
    required this.textMuted,
    required this.highlight,
    required this.border,
    required this.borderMuted,
    required this.primary,
    required this.primaryMuted,
    required this.secondary,
    required this.secondaryMuted,
    required this.danger,
    required this.warning,
    required this.success,
    required this.info,
  });

  /// Default theme with HSL colors (dark-green-tee configuration)
  factory AppTheme.defaultTheme() {
    return AppTheme(
      // hsl(349, 7%, 4%) - Very dark (bgDark)
      bgDark: const HSLColor.fromAHSL(1.0, 349, 0.07, 0.04).toColor(),
      // hsl(349, 7%, 8%) - Dark (bg)
      bg: const HSLColor.fromAHSL(1.0, 349, 0.07, 0.08).toColor(),
      // hsl(349, 7%, 12%) - Slightly lighter dark (bgLight)
      bgLight: const HSLColor.fromAHSL(1.0, 349, 0.07, 0.12).toColor(),
      // hsl(349, 7%, 91%) - Almost white (text)
      text: const HSLColor.fromAHSL(1.0, 349, 0.07, 0.91).toColor(),
      // hsl(349, 7%, 100%) - White (textMuted)
      textMuted: const HSLColor.fromAHSL(1.0, 349, 0.07, 1.0).toColor(),
      // hsl(349, 7%, 41%) - Medium gray (highlight)
      highlight: const HSLColor.fromAHSL(1.0, 349, 0.07, 0.41).toColor(),
      // hsl(349, 7%, 52%) - Light gray (border)
      border: const HSLColor.fromAHSL(1.0, 349, 0.07, 0.52).toColor(),
      // hsl(349, 7%, 40%) - Medium-light gray (borderMuted)
      borderMuted: const HSLColor.fromAHSL(1.0, 349, 0.07, 0.32).toColor(),
      // hsl(146, 17%, 59%) - Green (primary)
      primary: const HSLColor.fromAHSL(1.0, 146, 0.17, 0.59).toColor(),
      // hsl(146, 17%, 29.5%) - Dark green (primaryMuted)
      primaryMuted: const HSLColor.fromAHSL(1.0, 146, 0.04, 0.40).toColor(),
      // hsl(221, 79%, 76%) - Light blue (secondary)
      secondary: const HSLColor.fromAHSL(1.0, 221, 0.79, 0.76).toColor(),
      // hsl(221, 79%, 38%) - Medium blue (secondaryMuted)
      secondaryMuted: const HSLColor.fromAHSL(1.0, 221, 0.79, 0.38).toColor(),
      // hsl(9, 26%, 64%) - Reddish (danger)
      danger: const HSLColor.fromAHSL(1.0, 9, 0.26, 0.64).toColor(),
      // hsl(52, 19%, 57%) - Yellowish (warning)
      warning: const HSLColor.fromAHSL(1.0, 52, 0.19, 0.57).toColor(),
      // hsl(146, 17%, 59%) - Greenish (success)
      success: const HSLColor.fromAHSL(1.0, 146, 0.17, 0.59).toColor(),
      // hsl(217, 28%, 65%) - Blueish (info)
      info: const HSLColor.fromAHSL(1.0, 252, 0.17, 0.59).toColor(),
    );
  }

  /// Creates a theme from configuration values.
  ///
  /// All colors are directly specified via HSL values - no computation.
  factory AppTheme.fromConfig({
    required double bgH,
    required double bgS,
    required double bgL,
    required double bgLightH,
    required double bgLightS,
    required double bgLightL,
    required double bgDarkH,
    required double bgDarkS,
    required double bgDarkL,
    required double primaryH,
    required double primaryS,
    required double primaryL,
    required double primaryMutedH,
    required double primaryMutedS,
    required double primaryMutedL,
    required double secondaryH,
    required double secondaryS,
    required double secondaryL,
    required double secondaryMutedH,
    required double secondaryMutedS,
    required double secondaryMutedL,
    required double textH,
    required double textS,
    required double textL,
    required double textMutedH,
    required double textMutedS,
    required double textMutedL,
    required double successH,
    required double successS,
    required double successL,
    required double dangerH,
    required double dangerS,
    required double dangerL,
    required double highlightH,
    required double highlightS,
    required double highlightL,
    required double borderH,
    required double borderS,
    required double borderL,
    required double borderMutedH,
    required double borderMutedS,
    required double borderMutedL,
  }) {
    // Keep warning and info from default theme
    final defaultTheme = AppTheme.defaultTheme();
    final warning = defaultTheme.warning;
    final info = defaultTheme.info;

    return AppTheme(
      bgDark: HSLColor.fromAHSL(1.0, bgDarkH, bgDarkS, bgDarkL.clamp(0.0, 1.0))
          .toColor(),
      bg: HSLColor.fromAHSL(1.0, bgH, bgS, bgL.clamp(0.0, 1.0)).toColor(),
      bgLight:
          HSLColor.fromAHSL(1.0, bgLightH, bgLightS, bgLightL.clamp(0.0, 1.0))
              .toColor(),
      text:
          HSLColor.fromAHSL(1.0, textH, textS, textL.clamp(0.0, 1.0)).toColor(),
      textMuted: HSLColor.fromAHSL(
              1.0, textMutedH, textMutedS, textMutedL.clamp(0.0, 1.0))
          .toColor(),
      highlight: HSLColor.fromAHSL(
              1.0, highlightH, highlightS, highlightL.clamp(0.0, 1.0))
          .toColor(),
      border: HSLColor.fromAHSL(1.0, borderH, borderS, borderL.clamp(0.0, 1.0))
          .toColor(),
      borderMuted: HSLColor.fromAHSL(
              1.0, borderMutedH, borderMutedS, borderMutedL.clamp(0.0, 1.0))
          .toColor(),
      primary:
          HSLColor.fromAHSL(1.0, primaryH, primaryS, primaryL.clamp(0.0, 1.0))
              .toColor(),
      primaryMuted: HSLColor.fromAHSL(
              1.0, primaryMutedH, primaryMutedS, primaryMutedL.clamp(0.0, 1.0))
          .toColor(),
      secondary: HSLColor.fromAHSL(
              1.0, secondaryH, secondaryS, secondaryL.clamp(0.0, 1.0))
          .toColor(),
      secondaryMuted: HSLColor.fromAHSL(1.0, secondaryMutedH, secondaryMutedS,
              secondaryMutedL.clamp(0.0, 1.0))
          .toColor(),
      danger: HSLColor.fromAHSL(1.0, dangerH, dangerS, dangerL.clamp(0.0, 1.0))
          .toColor(),
      warning: warning,
      success:
          HSLColor.fromAHSL(1.0, successH, successS, successL.clamp(0.0, 1.0))
              .toColor(),
      info: info,
    );
  }

  @override
  AppTheme copyWith({
    Color? bgDark,
    Color? bg,
    Color? bgLight,
    Color? text,
    Color? textMuted,
    Color? highlight,
    Color? border,
    Color? borderMuted,
    Color? primary,
    Color? primaryMuted,
    Color? secondary,
    Color? secondaryMuted,
    Color? danger,
    Color? warning,
    Color? success,
    Color? info,
  }) {
    return AppTheme(
      bgDark: bgDark ?? this.bgDark,
      bg: bg ?? this.bg,
      bgLight: bgLight ?? this.bgLight,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      highlight: highlight ?? this.highlight,
      border: border ?? this.border,
      borderMuted: borderMuted ?? this.borderMuted,
      primary: primary ?? this.primary,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      secondary: secondary ?? this.secondary,
      secondaryMuted: secondaryMuted ?? this.secondaryMuted,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      info: info ?? this.info,
    );
  }

  @override
  AppTheme lerp(ThemeExtension<AppTheme>? other, double t) {
    if (other is! AppTheme) {
      return this;
    }
    return AppTheme(
      bgDark: Color.lerp(bgDark, other.bgDark, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      bgLight: Color.lerp(bgLight, other.bgLight, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderMuted: Color.lerp(borderMuted, other.borderMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryMuted: Color.lerp(primaryMuted, other.primaryMuted, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryMuted: Color.lerp(secondaryMuted, other.secondaryMuted, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}
