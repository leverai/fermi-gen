// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// CustomPainter for the AnswerAccuracyScale widget.
///
/// Draws the logarithmic scale ruler, ticks, labels, and answer indicators.
class ScalePainter extends CustomPainter {
  ScalePainter({
    required this.userLogValue,
    required this.correctLogValue,
    required this.revealProgress,
    required this.appTheme,
    required this.revealedColor,
    required this.labelTextStyle,
    this.otherPlayersLogValues = const <String, double>{},
    this.otherPlayersAvatars = const <String, String?>{},
    this.acceptableRangeLower,
    this.acceptableRangeUpper,
  });

  final double userLogValue;
  final double? correctLogValue;
  final double revealProgress;
  final AppTheme appTheme;
  final Color? revealedColor;
  final TextStyle labelTextStyle;
  final Map<String, double> otherPlayersLogValues;
  final Map<String, String?> otherPlayersAvatars;

  /// Lower bound of acceptable range (log scale 0-15), for survival mode
  final double? acceptableRangeLower;

  /// Upper bound of acceptable range (log scale 0-15), for survival mode
  final double? acceptableRangeUpper;

  // Constants

  static const double maxLog = 15.0; // 10^15 = 1 Trillion
  static const double tickHeight = 8.0;
  static const double rulerHeight = 4.0;
  static const double indicatorSize = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2;

    // Calculate pulse for size animation (starts at 0, peaks, ends at 0)
    // We clamp to 0.0 to handle potential negative values from elastic overshoot
    final sizePulse = math.max(0.0, math.sin(revealProgress * math.pi));

    // Paint for the ruler line
    final rulerPaint = Paint()
      ..color = Colors.transparent
      ..strokeWidth = rulerHeight
      ..strokeCap = StrokeCap.round;

    // Paint for ticks
    final tickPaint = Paint()
      ..color = appTheme.textMuted
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw Ruler
    // We add some padding horizontally for the indicators
    const padding = 12.0;
    final drawWidth = w - (padding * 2);

    canvas.drawLine(
      Offset(padding, cy),
      Offset(w - padding, cy),
      rulerPaint,
    );

    // Draw Ticks
    // Ticks at 0, 1, 2, ... 15 (Powers of 10)
    for (int i = 0; i <= 15; i++) {
      // Draw Minor Ticks (Dots) for values 2..9 within this decade
      // i is the start of decade. i+1 is end.
      // We want dots at i + 1/9, i + 2/9 ... i + 8/9
      if (i < 15) {
        for (int j = 1; j <= 8; j++) {
          final sliderVal = i + (j / 9.0);
          final x = padding + (sliderVal / maxLog) * drawWidth;

          // Check if dot is within acceptable range (for survival mode)
          final bool inAcceptableRange = acceptableRangeLower != null &&
              acceptableRangeUpper != null &&
              sliderVal >= acceptableRangeLower! &&
              sliderVal <= acceptableRangeUpper! &&
              revealProgress > 0;

          final dotColor = inAcceptableRange
              ? Color.lerp(
                  appTheme.textMuted.withAlpha(50),
                  appTheme.success,
                  revealProgress,
                )!
              : appTheme.textMuted.withAlpha(50);

          // Animated size for acceptable range dots
          final double dotRadius = inAcceptableRange
              ? 1.0 + (1.5 * sizePulse) // Grow from 1.0 to 2.5 then back to 1.0
              : 1.0;

          final dotPaint = Paint()
            ..color = dotColor
            ..style = PaintingStyle.fill;

          canvas.drawCircle(Offset(x, cy), dotRadius, dotPaint);
        }
      }

      final x = padding + (i / maxLog) * drawWidth;

      final isOmBoundary = i % 3 == 0;
      final baseTickHeight = isOmBoundary ? tickHeight * 1.5 : tickHeight;

      // Check if tick is within acceptable range
      final bool tickInRange = acceptableRangeLower != null &&
          acceptableRangeUpper != null &&
          i.toDouble() >= acceptableRangeLower! &&
          i.toDouble() <= acceptableRangeUpper! &&
          revealProgress > 0;

      // Animate tick height for acceptable range
      final double currentTickHeight = tickInRange
          ? baseTickHeight * (1.0 + 0.3 * sizePulse) // Pulse by 30%
          : baseTickHeight;

      final Color tickColor;
      if (tickInRange) {
        tickColor = Color.lerp(
          isOmBoundary ? appTheme.border : appTheme.borderMuted,
          appTheme.success,
          revealProgress,
        )!;
      } else {
        tickColor = isOmBoundary ? appTheme.border : appTheme.borderMuted;
      }

      canvas.drawLine(
        Offset(x, cy - currentTickHeight / 2),
        Offset(x, cy + currentTickHeight / 2),
        tickPaint..color = tickColor,
      );

      // Draw Labels
      // Requirement: "The first and last ticks have no label" -> skip 0 and 15
      // Requirement: "Use abbreviation (K, M, B, etc.)" -> implies only OM ticks
      if (isOmBoundary && i > 0 && i < 15) {
        String? label;
        switch (i) {
          case 3:
            label = 'Thousand';
            break;
          case 6:
            label = 'Million';
            break;
          case 9:
            label = 'Billion';
            break;
          case 12:
            label = 'Trillion';
            break;
        }

        if (label != null) {
          final textSpan = TextSpan(
            text: label,
            style: labelTextStyle,
          );
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();

          // Position: "Ticks labels should be directly below the ticks"
          // Center the text horizontally on x
          // Place it below the tick. Tick ends at cy + currentTickHeight / 2
          final textX = x - (textPainter.width / 2);
          final textY = cy + (currentTickHeight / 2) + 4; // +4 padding

          textPainter.paint(canvas, Offset(textX, textY));
        }
      }
    }

    // Draw Other Players' Indicators (with full opacity as lines)
    otherPlayersLogValues.forEach((playerId, logValue) {
      final clampedLogValue = logValue.clamp(0.0, maxLog);
      final x = padding + (clampedLogValue / maxLog) * drawWidth;
      // Requirement: "other-players' lines are borderMuted"
      _drawIndicator(
        canvas,
        Offset(x, cy),
        appTheme.borderMuted.withOpacity(0.5),
      );
    });

    // Draw User Indicator
    final userX = padding + (userLogValue / maxLog) * drawWidth;
    // Requirement: "My line should appear in secondary"
    _drawIndicator(
      canvas,
      Offset(userX, cy),
      appTheme.secondary,
    );

    // Draw Correct Indicator (if revealed)
    if (correctLogValue != null) {
      final correctX = padding + (correctLogValue! / maxLog) * drawWidth;

      // Lerp position
      final currentX = userX + (correctX - userX) * revealProgress;

      // Requirement: "The correct answer appears as a line as well, primary colored."
      _drawIndicator(
        canvas,
        Offset(currentX, cy),
        appTheme.primary,
      );
    }
  }

  void _drawIndicator(Canvas canvas, Offset tip, Color color) {
    const double size = 16.0;
    const double radius = 1.0;
    const double strokeWidth = radius * 2;

    final p = Path();
    // Inset the path by half the stroke width to keep the total size close to 'size'
    // and offset down by strokeWidth/2 to keep the tip at the exact 'tip' location.
    const double halfWidth = (size - strokeWidth) / 2;
    const double height = size - strokeWidth;
    const double topOffset = strokeWidth / 2;

    p.moveTo(tip.dx, tip.dy + topOffset);
    p.lineTo(tip.dx - halfWidth, tip.dy + topOffset + height);
    p.lineTo(tip.dx + halfWidth, tip.dy + topOffset + height);
    p.close();

    final paint = Paint()
      ..color = color
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    // Draw both fill and stroke to get rounded corners on a filled shape
    canvas.drawPath(p, paint..style = PaintingStyle.fill);
    canvas.drawPath(p, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant ScalePainter oldDelegate) {
    return oldDelegate.userLogValue != userLogValue ||
        oldDelegate.correctLogValue != correctLogValue ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.appTheme != appTheme ||
        oldDelegate.revealedColor != revealedColor ||
        oldDelegate.labelTextStyle != labelTextStyle ||
        oldDelegate.otherPlayersLogValues != otherPlayersLogValues ||
        oldDelegate.acceptableRangeLower != acceptableRangeLower ||
        oldDelegate.acceptableRangeUpper != acceptableRangeUpper;
  }
}
