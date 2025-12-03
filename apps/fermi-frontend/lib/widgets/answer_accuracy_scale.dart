import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/utils/om_constants.dart';

/// A widget that displays the answer on a logarithmic scale.
///
/// Range: 0 (1) to 18 (1 Quintillion).
/// Shows ticks for each order of magnitude.
/// During reveal, animates a second indicator from the user's answer to the correct answer.
class AnswerAccuracyScale extends StatefulWidget {
  const AnswerAccuracyScale({
    super.key,
    required this.currentAnswer,
    this.submittedAnswer,
    this.revealedAnswer,
    this.revealedColor,
    this.editable = true,
  });

  final AnswerValue currentAnswer;
  final AnswerValue? submittedAnswer;
  final AnswerValue? revealedAnswer;
  final Color? revealedColor;
  final bool editable;

  @override
  State<AnswerAccuracyScale> createState() => _AnswerAccuracyScaleState();
}

class _AnswerAccuracyScaleState extends State<AnswerAccuracyScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    if (widget.revealedAnswer != null) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AnswerAccuracyScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealedAnswer != null && oldWidget.revealedAnswer == null) {
      _controller.forward(from: 0.0);
    } else if (widget.revealedAnswer == null &&
        oldWidget.revealedAnswer != null) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getLogValue(AnswerValue value) {
    final exponent = orderOfMagnitudePowers[value.orderOfMagnitude] ?? 0;
    // log10(number). number is 1..999.
    // log10(1) = 0
    // log10(10) = 1
    // log10(100) = 2
    // log10(999) ~ 3
    final logNum = math.log(value.number) / math.ln10;
    return exponent + logNum;
  }

  String _formatAnswerText(AnswerValue value) {
    if (value.rawValue != null) {
      final double raw = value.rawValue!;
      // Check if out of bounds (same logic as decomposeNumber)
      const double maxDisplayable = 999e15;
      if (raw < 1 || raw > maxDisplayable) {
        // Use scientific notation
        // Remove trailing zeros and + sign if preferred, but standard is fine
        return raw.toStringAsExponential(2);
      }
    }
    // Fallback to decomposed format (without unit since both answers have the same unit)
    return '${value.number} ${value.orderOfMagnitude}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Determine which answer to show as the "User Answer"
    // If revealed (not editable + submitted exists), show submitted.
    // Otherwise show current.
    final userAnswer = (!widget.editable && widget.submittedAnswer != null)
        ? widget.submittedAnswer!
        : widget.currentAnswer;

    final userLogValue = _getLogValue(userAnswer);

    // Clip correct log value to 0..18 range for the circle position
    // But we use the raw value for the text
    double? correctLogValue;
    if (widget.revealedAnswer != null) {
      final rawLog = _getLogValue(widget.revealedAnswer!);
      correctLogValue = rawLog.clamp(0.0, 18.0);
    }

    return SizedBox(
      height: 48, // Fixed height as per requirements
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          const padding = 12.0;
          final drawWidth = w - (padding * 2);

          return AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              // Calculate correct indicator position
              double? currentCorrectX;
              if (correctLogValue != null) {
                final userX = padding + (userLogValue / 18.0) * drawWidth;
                final correctX = padding + (correctLogValue / 18.0) * drawWidth;
                currentCorrectX = userX + (correctX - userX) * _animation.value;
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: Size(w, 48),
                    painter: _ScalePainter(
                      userLogValue: userLogValue,
                      correctLogValue: correctLogValue,
                      revealProgress: _animation.value,
                      appTheme: appTheme,
                      revealedColor: widget.revealedColor,
                    ),
                  ),
                  // User Answer Text Box
                  Positioned(
                    left: padding + (userLogValue / 18.0) * drawWidth,
                    top: -14, // Position above the scale
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: appTheme.bgLight,
                          border: Border.all(color: appTheme.border, width: 1),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: appTheme.shadowColor.withOpacity(0.1),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          _formatAnswerText(userAnswer),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: appTheme.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Correct Answer Text Box
                  if (currentCorrectX != null && widget.revealedAnswer != null)
                    Positioned(
                      left: currentCorrectX,
                      bottom: -14, // Position above the scale
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: Opacity(
                          opacity: _animation.value
                              .clamp(0.0, 1.0), // Fade in with movement
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: appTheme.primary,
                              border:
                                  Border.all(color: appTheme.border, width: 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatAnswerText(widget.revealedAnswer!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: appTheme.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ScalePainter extends CustomPainter {
  _ScalePainter({
    required this.userLogValue,
    required this.correctLogValue,
    required this.revealProgress,
    required this.appTheme,
    required this.revealedColor,
  });

  final double userLogValue;
  final double? correctLogValue;
  final double revealProgress;
  final AppTheme appTheme;
  final Color? revealedColor;

  // Constants

  static const double maxLog = 18.0; // 10^18 = 1 Quintillion
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
    // Ticks at 0, 1, 2, ... 18
    for (int i = 0; i <= 18; i++) {
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
      // Requirement: "The first and last ticks have no label" -> skip 0 and 18
      // Requirement: "Use abbreviation (K, M, B, etc.)" -> implies only major ticks
      if (isMajor && i > 0 && i < 18) {
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
          case 15:
            label = 'Qa';
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
      {double scale = 1.0}) {
    final paint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Shape: Circle or Rounded Rect?
    // Neubrutalism often uses simple geometric shapes.
    // Let's use a Circle.

    canvas.drawCircle(center, (indicatorSize / 2) * scale, paint);
    canvas.drawCircle(center, (indicatorSize / 2) * scale, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScalePainter oldDelegate) {
    return oldDelegate.userLogValue != userLogValue ||
        oldDelegate.correctLogValue != correctLogValue ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.appTheme != appTheme ||
        oldDelegate.revealedColor != revealedColor;
  }
}
