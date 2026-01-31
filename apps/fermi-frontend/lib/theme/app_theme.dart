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
  // Brand colors
  final Color primary;
  final Color primaryMuted;
  final Color secondary;
  final Color secondaryMuted;
  final Color survival;
  final Color survivalMuted;

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
    required this.survival,
    required this.survivalMuted,
    required this.danger,
    required this.warning,
    required this.success,
    required this.gold,
    required this.silver,
    required this.bronze,
    this.borderWidth = 1.0,
    this.borderRadius = 16.0, // Increased radius for softer look
    this.shadowOffset =
        const Offset(0, 4), // Soft drop shadow instead of brutalist offset
    this.shadowColor = const Color(0x40000000), // Soft black shadow
  });

  /// Default theme with "Happy Dark" colors
  factory AppTheme.defaultTheme() {
    return AppTheme(
      // Backgrounds - Cool Slate Dark
      bgDark: const HSLColor.fromAHSL(1.0, 220, 0.20, 0.10).toColor(),
      bg: const HSLColor.fromAHSL(1.0, 220, 0.20, 0.14).toColor(),
      bgLight: const HSLColor.fromAHSL(1.0, 220, 0.20, 0.18).toColor(),

      // Text - Soft White & Cool Grey
      text: const HSLColor.fromAHSL(1.0, 220, 0.20, 0.95).toColor(),
      textMuted: const HSLColor.fromAHSL(1.0, 220, 0.15, 0.65).toColor(),

      // UI Elements
      highlight: const HSLColor.fromAHSL(1.0, 220, 0.20, 0.45).toColor(),
      border: const HSLColor.fromAHSL(1.0, 220, 0.15, 0.4).toColor(),
      borderMuted: const HSLColor.fromAHSL(1.0, 220, 0.15, 0.35).toColor(),

      // Brand (Daily) - Soft Vibrant Indigo
      primary: const HSLColor.fromAHSL(1.0, 250, 0.70, 0.65).toColor(),
      primaryMuted: const HSLColor.fromAHSL(1.0, 250, 0.50, 0.25).toColor(),

      // Secondary (Party) - Soft Vibrant Pink
      secondary: const HSLColor.fromAHSL(1.0, 330, 0.80, 0.65).toColor(),
      secondaryMuted: const HSLColor.fromAHSL(1.0, 330, 0.60, 0.25).toColor(),

      // Survival - Soft Vibrant Orange
      survival: const HSLColor.fromAHSL(1.0, 30, 0.90, 0.60).toColor(),
      survivalMuted: const HSLColor.fromAHSL(1.0, 30, 0.70, 0.25).toColor(),

      // Semantic
      danger:
          const HSLColor.fromAHSL(1.0, 350, 0.80, 0.65).toColor(), // Soft Red
      warning:
          const HSLColor.fromAHSL(1.0, 45, 0.90, 0.60).toColor(), // Soft Yellow
      success:
          const HSLColor.fromAHSL(1.0, 150, 0.60, 0.55).toColor(), // Soft Green

      // Rank Colors
      gold: const HSLColor.fromAHSL(1.0, 45, 0.90, 0.60).toColor(),
      silver: const HSLColor.fromAHSL(1.0, 210, 0.20, 0.75).toColor(),
      bronze: const HSLColor.fromAHSL(1.0, 30, 0.60, 0.50).toColor(),

      // Shadow
      shadowColor:
          Basics.black.withOpacity(0.2), // Use simple opacity for soft shadows
      shadowOffset: const Offset(0, 4),
    );
  }

  /// Light theme with "Happy Light" colors
  factory AppTheme.lightTheme() {
    return AppTheme(
      // Backgrounds - Warm Soft White
      bgDark:
          const HSLColor.fromAHSL(1.0, 40, 0.10, 0.87).toColor(), // Off-white
      bg: const HSLColor.fromAHSL(1.0, 40, 0.10, 0.93).toColor(), // Near white
      bgLight:
          const HSLColor.fromAHSL(1.0, 0, 0.0, 0.98).toColor(), // Pure white

      // Text - Dark Slate
      text: const HSLColor.fromAHSL(1.0, 220, 0.30, 0.15).toColor(),
      textMuted: const HSLColor.fromAHSL(1.0, 220, 0.15, 0.4).toColor(),

      // UI Elements
      highlight: const HSLColor.fromAHSL(1.0, 220, 0.20, 0.55).toColor(),
      border: const HSLColor.fromAHSL(1.0, 220, 0.15, 0.6).toColor(),
      borderMuted: const HSLColor.fromAHSL(1.0, 220, 0.10, 0.65).toColor(),

      // Brand (Daily) - Deep Vibrant Indigo
      primary: const HSLColor.fromAHSL(1.0, 250, 0.70, 0.55).toColor(),
      primaryMuted: const HSLColor.fromAHSL(1.0, 250, 0.50, 0.3).toColor(),

      // Secondary (Party) - Deep Vibrant Pink
      secondary: const HSLColor.fromAHSL(1.0, 330, 0.80, 0.55).toColor(),
      secondaryMuted: const HSLColor.fromAHSL(1.0, 330, 0.60, 0.3).toColor(),

      // Survival - Deep Vibrant Orange
      survival: const HSLColor.fromAHSL(1.0, 30, 0.90, 0.5).toColor(),
      survivalMuted: const HSLColor.fromAHSL(1.0, 30, 0.70, 0.90).toColor(),

      // Semantic
      danger: const HSLColor.fromAHSL(1.0, 350, 0.80, 0.55).toColor(),
      warning: const HSLColor.fromAHSL(1.0, 45, 0.90, 0.50).toColor(),
      success: const HSLColor.fromAHSL(1.0, 150, 0.60, 0.45).toColor(),

      // Rank Colors
      gold: const HSLColor.fromAHSL(1.0, 45, 0.90, 0.55).toColor(),
      silver: const HSLColor.fromAHSL(1.0, 210, 0.20, 0.60).toColor(),
      bronze: const HSLColor.fromAHSL(1.0, 30, 0.60, 0.55).toColor(),

      shadowColor: Basics.black.withOpacity(0.1),
      shadowOffset: const Offset(0, 2),
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
    Color? survival,
    Color? survivalMuted,
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
      survival: survival ?? this.survival,
      survivalMuted: survivalMuted ?? this.survivalMuted,
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
      survival: Color.lerp(survival, other.survival, t)!,
      survivalMuted: Color.lerp(survivalMuted, other.survivalMuted, t)!,
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

class Basics {
  static const Color black = Colors.black;
}

double? lerpDouble(double? a, double? b, double t) {
  if (a == null && b == null) return null;
  a ??= 0.0;
  b ??= 0.0;
  return a + (b - a) * t;
}
