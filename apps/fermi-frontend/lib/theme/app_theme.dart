import 'package:flutter/material.dart';

/// Global app theme that provides consistent colors across the application.
/// These colors are used for backgrounds, text, borders, and semantic colors
/// throughout the app.
///
/// Colors are defined using HSL (Hue, Saturation, Lightness) values and converted
/// to RGB Color objects using Flutter's HSLColor class.
@immutable
class AppTheme extends ThemeExtension<AppTheme> {
  // Background colors
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

  // Rank colors
  final Color gold;
  final Color silver;
  final Color bronze;

  // Neubrutalism specific properties
  final double borderWidth;
  final double borderRadius;
  final Offset shadowOffset;
  final Color shadowColor;

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
    required this.gold,
    required this.silver,
    required this.bronze,
    this.borderWidth = 1.0,
    this.borderRadius = 12.0,
    this.shadowOffset = const Offset(4, 4),
    this.shadowColor = Colors.black,
  });

  /// Default theme with Neubrutalism colors
  factory AppTheme.defaultTheme() {
    return AppTheme(
      // Backgrounds
      bgDark: const HSLColor.fromAHSL(1.0, 90, 0.01, 0.10).toColor(),
      bg: const HSLColor.fromAHSL(1.0, 90, 0.01, 0.17).toColor(),
      bgLight: const HSLColor.fromAHSL(1.0, 90, 0.01, 0.24).toColor(),

      // Text
      text: const HSLColor.fromAHSL(1.0, 40, 0.93, 0.97).toColor(),
      textMuted: const HSLColor.fromAHSL(1.0, 30, 0.11, 0.6).toColor(),

      // UI Elements
      highlight: const HSLColor.fromAHSL(1.0, 144, 0.1, 0.82).toColor(),
      border: const HSLColor.fromAHSL(1.0, 144, 0.05, 0.52).toColor(),
      borderMuted: const HSLColor.fromAHSL(1.0, 144, 0.05, 0.32).toColor(),

      // Brand - Vibrant Purple
      primary: const HSLColor.fromAHSL(1.0, 144, 0.21, 0.49).toColor(),
      primaryMuted: const HSLColor.fromAHSL(1.0, 144, 0.21, 0.30).toColor(),

      // Secondary - Vibrant Teal
      secondary: const HSLColor.fromAHSL(1.0, 4, .71, 0.62).toColor(),
      secondaryMuted: const HSLColor.fromAHSL(1.0, 4, .71, 0.32).toColor(),

      // Semantic
      danger: const HSLColor.fromAHSL(1.0, 4, .71, 0.62).toColor(),
      warning: const HSLColor.fromAHSL(1.0, 53, 1.0, 0.70).toColor(),
      success: const HSLColor.fromAHSL(1.0, 144, 0.21, 0.49).toColor(),

      // Rank Colors
      gold: const HSLColor.fromAHSL(1.0, 48, 1.0, 0.50).toColor(),
      silver: const HSLColor.fromAHSL(1.0, 210, 0.1, 0.75).toColor(),
      bronze: const HSLColor.fromAHSL(1.0, 30, 0.7, 0.50).toColor(),

      // Shadow
      shadowColor: const HSLColor.fromAHSL(1.0, 90, 0.01, 0.10).toColor(),
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
    Color? gold,
    Color? silver,
    Color? bronze,
    double? borderWidth,
    double? borderRadius,
    Offset? shadowOffset,
    Color? shadowColor,
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
      gold: gold ?? this.gold,
      silver: silver ?? this.silver,
      bronze: bronze ?? this.bronze,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      shadowColor: shadowColor ?? this.shadowColor,
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
      gold: Color.lerp(gold, other.gold, t)!,
      silver: Color.lerp(silver, other.silver, t)!,
      bronze: Color.lerp(bronze, other.bronze, t)!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t)!,
      borderRadius: lerpDouble(borderRadius, other.borderRadius, t)!,
      shadowOffset: Offset.lerp(shadowOffset, other.shadowOffset, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}

double? lerpDouble(double? a, double? b, double t) {
  if (a == null && b == null) return null;
  a ??= 0.0;
  b ??= 0.0;
  return a + (b - a) * t;
}
