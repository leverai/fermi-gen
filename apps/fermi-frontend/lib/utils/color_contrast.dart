import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Compute a readable text color against a given background color.
/// Prefers theme foregrounds when provided; otherwise falls back to black/white
/// by relative luminance. This utility is intentionally small and dependency-free
/// so it can be reused across widgets.
Color pickContrastingTextColor({
  required Color background,
  Color? preferredLightText,
  Color? preferredDarkText,
}) {
  // If background is dark, choose light text; otherwise choose dark text.
  final double luminance = background.computeLuminance();
  final bool isDarkBg = luminance < 0.5;
  if (isDarkBg) {
    return preferredLightText ?? Colors.white;
  }
  return preferredDarkText ?? Colors.black;
}

/// Compute WCAG relative luminance for a color (sRGB → linearized).
double _relativeLuminance(Color c) {
  double toLinear(int channel) {
    final double x = channel / 255.0;
    return x <= 0.03928
        ? x / 12.92
        : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
  }

  // ignore: deprecated_member_use
  final double r = toLinear(c.red);
  // ignore: deprecated_member_use
  final double g = toLinear(c.green);
  // ignore: deprecated_member_use
  final double b = toLinear(c.blue);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Contrast ratio per WCAG 2.1.
double _contrastRatio(Color a, Color b) {
  final double l1 = _relativeLuminance(a);
  final double l2 = _relativeLuminance(b);
  final double hi = math.max(l1, l2);
  final double lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/// Pick black or white — whichever has higher contrast against [background].
Color bestOn(Color background) {
  final double cw = _contrastRatio(background, Colors.white);
  final double cb = _contrastRatio(background, Colors.black);
  return cw >= cb ? Colors.white : Colors.black;
}
