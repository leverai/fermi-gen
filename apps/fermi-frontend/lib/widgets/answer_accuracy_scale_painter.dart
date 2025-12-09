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
      ..color = appTheme.borderMuted
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
    // Ticks at 0, 1, 2, ... 15
    for (int i = 0; i <= 15; i++) {
      final x = padding + (i / maxLog) * drawWidth;
      // Make major ticks (0, 3, 6, 9, 12, 15, 18) slightly larger/darker?
      // Requirement: "tick for each order of magnitude starting from zero"
      // 0, 10, 100... means every integer power of 10.
      // So every integer on the log scale.

      // Let's make the OM ticks (0, 3, 6...) more prominent
      final isMajor = i % 3 == 0;
      final currentTickHeight = isMajor ? tickHeight * 1.5 : tickHeight;

      canvas.drawLine(
        Offset(x, cy - currentTickHeight / 2),
        Offset(x, cy + currentTickHeight / 2),
        tickPaint..color = isMajor ? appTheme.border : appTheme.borderMuted,
      );

      // Draw Labels
      // Requirement: "The first and last ticks have no label" -> skip 0 and 15
      // Requirement: "Use abbreviation (K, M, B, etc.)" -> implies only major ticks
      if (isMajor && i > 0 && i < 15) {
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
              fontWeight: FontWeight.w400,
              color: appTheme.borderMuted,
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
          final textY = cy + (currentTickHeight / 2) + 2; // +2 padding

          textPainter.paint(canvas, Offset(textX, textY));
        }
      }
    }

    // Draw Other Players' Indicators (with 0.5 opacity)
    otherPlayersLogValues.forEach((playerId, logValue) {
      final clampedLogValue = logValue.clamp(0.0, maxLog);
      final x = padding + (clampedLogValue / maxLog) * drawWidth;
      final avatarUrl = otherPlayersAvatars[playerId];
      _drawIndicator(
        canvas,
        Offset(x, cy),
        appTheme.border,
        appTheme.bgLight,
        opacity: 0.5,
        avatarUrl: avatarUrl,
      );
    });

    // Draw User Indicator
    final userX = padding + (userLogValue / maxLog) * drawWidth;
    _drawIndicator(
      canvas,
      Offset(userX, cy),
      appTheme.border,
      appTheme.bgLight,
    );

    // Draw Correct Indicator (if revealed)
    if (correctLogValue != null) {
      final correctX = padding + (correctLogValue! / maxLog) * drawWidth;

      // Lerp position
      final currentX = userX + (correctX - userX) * revealProgress;

      // Only draw if progress > 0 to avoid z-fighting at start if we want
      // But since it spawns from user, drawing on top is fine.

      // Color: revealedColor (usually green/red scale) or primary
      // Requirement 5: "The correct answer indicator must appear in primary at reveal time."
      // Wait, "appear in primary". But Requirement 0 says "Animates to score-scale (danger to success)".
      // Ah, the *card background* animates to score-scale.
      // The *indicator*? "The correct answer indicator must appear in primary at reveal time."
      // Okay, I'll use primary.

      final indicatorColor = appTheme.primary;

      // We can also fade it in or scale it up
      // But "spawns out of" implies movement.

      _drawIndicator(
        canvas,
        Offset(currentX, cy),
        appTheme.border, // Border color
        indicatorColor, // Fill color
        scale: 1.0, // Could animate scale if desired
      );
    }
  }

  void _drawIndicator(
      Canvas canvas, Offset center, Color borderColor, Color fillColor,
      {double scale = 1.0, double opacity = 1.0, String? avatarUrl}) {
    final paint = Paint()
      ..color = fillColor.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor.withOpacity(opacity)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Shape: Circle or Rounded Rect?
    // Neubrutalism often uses simple geometric shapes.
    // Let's use a Circle.

    // Note: Drawing avatars in CustomPainter requires pre-loaded ui.Image objects.
    // Since CustomPainter.paint() is synchronous and cannot load images,
    // we'll need to handle avatar rendering differently - either by:
    // 1. Pre-loading images in the widget state and passing ui.Image objects
    // 2. Using a Widget overlay approach instead of painting
    // For now, we'll draw the background circle and border as before.
    // Avatar rendering will be handled via Widget overlays in the parent widget.

    canvas.drawCircle(center, (indicatorSize / 2) * scale, paint);
    canvas.drawCircle(center, (indicatorSize / 2) * scale, borderPaint);
  }

  @override
  bool shouldRepaint(covariant ScalePainter oldDelegate) {
    return oldDelegate.userLogValue != userLogValue ||
        oldDelegate.correctLogValue != correctLogValue ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.appTheme != appTheme ||
        oldDelegate.revealedColor != revealedColor ||
        oldDelegate.otherPlayersLogValues != otherPlayersLogValues ||
        oldDelegate.otherPlayersAvatars != otherPlayersAvatars;
  }
}
