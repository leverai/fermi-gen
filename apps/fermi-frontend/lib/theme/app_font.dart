import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide font configuration provided via ThemeExtension.
/// Holds the single source of truth for primary and secondary font family names.
///
/// Primary Font (Barlow): Used for UI text, labels, buttons, questions, and general content
/// Secondary Font (Jura): Used for numbers, scores, answers, and numeric displays
@immutable
class AppFont extends ThemeExtension<AppFont> {
  const AppFont({
    this.primaryFamily = 'Ubuntu',
    this.secondaryFamily = 'Ubuntu',
    this.useGoogleFonts = true,
  });

  final String primaryFamily;
  final String secondaryFamily;
  final bool useGoogleFonts; // If true, fonts use Google Fonts

  @override
  AppFont copyWith({
    String? primaryFamily,
    String? secondaryFamily,
    bool? useGoogleFonts,
  }) {
    return AppFont(
      primaryFamily: primaryFamily ?? this.primaryFamily,
      secondaryFamily: secondaryFamily ?? this.secondaryFamily,
      useGoogleFonts: useGoogleFonts ?? this.useGoogleFonts,
    );
  }

  @override
  ThemeExtension<AppFont> lerp(ThemeExtension<AppFont>? other, double t) {
    if (other is! AppFont) return this;
    // Font family is discrete; switch to the other at t >= 0.5 for smooth-ish updates.
    return t < 0.5 ? this : other;
  }

  /// Get the primary font family name (for UI text, labels, questions)
  static String primaryOf(BuildContext context, {String fallback = 'Barlow'}) {
    final AppFont? ext = Theme.of(context).extension<AppFont>();
    return ext?.primaryFamily.isNotEmpty == true
        ? ext!.primaryFamily
        : fallback;
  }

  /// Get the secondary font family name (for numbers, scores, numeric displays)
  static String secondaryOf(BuildContext context, {String fallback = 'Jura'}) {
    final AppFont? ext = Theme.of(context).extension<AppFont>();
    return ext?.secondaryFamily.isNotEmpty == true
        ? ext!.secondaryFamily
        : fallback;
  }

  /// Get a TextStyle with the primary font (for UI text, labels, buttons, questions)
  /// This handles both local fonts and Google Fonts automatically
  static TextStyle primaryTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    final AppFont? ext = Theme.of(context).extension<AppFont>();
    final bool useGoogle = ext?.useGoogleFonts ?? true;
    final String fontFamily = ext?.primaryFamily ?? 'Barlow';

    if (useGoogle) {
      return GoogleFonts.getFont(
        fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
      );
    } else {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
      );
    }
  }

  /// Get a TextStyle with the secondary font (for numbers, scores, numeric displays)
  /// This handles both local fonts and Google Fonts automatically
  static TextStyle secondaryTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    final AppFont? ext = Theme.of(context).extension<AppFont>();
    final bool useGoogle = ext?.useGoogleFonts ?? true;
    final String fontFamily = ext?.secondaryFamily ?? 'Jura';

    if (useGoogle) {
      return GoogleFonts.getFont(
        fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
      );
    } else {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
      );
    }
  }

  // Legacy compatibility - returns primary font family
  static String of(BuildContext context, {String fallback = 'Barlow'}) {
    return primaryOf(context, fallback: fallback);
  }
}
