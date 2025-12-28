// ignore_for_file: deprecated_member_use

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
    this.otherPlayersLogValues = const <String, double>{},
    this.otherPlayersAvatars = const <String, String?>{},
  });

  final double userLogValue;
  final double? correctLogValue;
  final double revealProgress;
  final AppTheme appTheme;
  final Color? revealedColor;
  final Map<String, double> otherPlayersLogValues;
  final Map<String, String?> otherPlayersAvatars;

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

    // Paint for the ruler line
    final rulerPaint = Paint()
      ..color = Colors.transparent
      ..strokeWidth = rulerHeight
      ..strokeCap = StrokeCap.round;

    // Paint for ticks
    final tickPaint = Paint()
      ..color = appTheme.borderMuted
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
        final dotPaint = Paint()
          ..color = appTheme.bgDark
          ..style = PaintingStyle.fill;

        for (int j = 1; j <= 8; j++) {
          final sliderVal = i + (j / 9.0);
          final x = padding + (sliderVal / maxLog) * drawWidth;
          canvas.drawCircle(Offset(x, cy), 1.0, dotPaint);
        }
      }

      final x = padding + (i / maxLog) * drawWidth;

      final isOmBoundary = i % 3 == 0;
      final currentTickHeight = isOmBoundary ? tickHeight * 1.5 : tickHeight;

      canvas.drawLine(
        Offset(x, cy - currentTickHeight / 2),
        Offset(x, cy + currentTickHeight / 2),
        tickPaint
          ..color = isOmBoundary ? appTheme.border : appTheme.borderMuted,
      );

      // Draw Labels
      // Requirement: "The first and last ticks have no label" -> skip 0 and 15
      // Requirement: "Use abbreviation (K, M, B, etc.)" -> implies only OM ticks
      if (isOmBoundary && i > 0 && i < 15) {
        String? label;
        switch (i) {
          case 3:
            label = 'K';
            break;
          case 6:
            label = 'M';
            break;
          case 9:
            label = 'B';
            break;
          case 12:
            label = 'T';
            break;
        }

        if (label != null) {
          final textSpan = TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: appTheme.border,
            ),
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
        oldDelegate.otherPlayersLogValues != otherPlayersLogValues;
    // removed otherPlayersAvatars check
  }
}
