import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// Map a raw value in [min, max] to t in [0,1].
/// Values outside range are clamped.
double normalizeToUnitInterval(double value, double min, double max) {
  if (max == min) return 0.0;
  return ((value - min) / (max - min)).clamp(0.0, 1.0);
}

/// Map percentile (0..100) to a color lerped between danger (0) and success (100).
/// Uses the app theme's danger and success colors.
Color percentileToColor(num percentile, {AppTheme? theme}) {
  final appTheme = theme ?? AppTheme.defaultTheme();
  final double t = normalizeToUnitInterval(percentile.toDouble(), 0.0, 100.0);
  return Color.lerp(appTheme.danger, appTheme.success, t)!;
}

/// Map score (0..maxScore) to a color lerped between danger (0) and success (max).
/// Uses the app theme's danger and success colors.
Color scoreToColor(num score, {num min = 0, num max = 6000, AppTheme? theme}) {
  final appTheme = theme ?? AppTheme.defaultTheme();
  final double t =
      normalizeToUnitInterval(score.toDouble(), min.toDouble(), max.toDouble());
  return Color.lerp(appTheme.danger, appTheme.success, t)!;
}
