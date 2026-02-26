import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/services/feedback_service.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/utils/answer_format.dart';
import 'package:fermi_frontend/utils/om_constants.dart';
import 'package:fermi_frontend/widgets/answer_accuracy_scale_painter.dart';

/// A widget that displays the answer on a logarithmic scale.
///
/// Range: 0 (1) to 15 (1 Trillion).
/// Shows ticks for each order of magnitude.
/// During reveal, animates a second indicator from the user's answer to the correct answer.
/// Supports interactive input via tap/drag gestures when editable and onAnswerChanged is provided.
class AnswerAccuracyScale extends StatefulWidget {
  const AnswerAccuracyScale({
    super.key,
    required this.currentAnswer,
    this.submittedAnswer,
    this.revealedAnswer,
    this.revealedColor,
    this.editable = true,
    this.otherPlayersAnswers,
    this.currentPlayerAvatarUrl,
    this.onAnswerChanged,
    this.acceptableRangeLower,
    this.acceptableRangeUpper,
  });

  final AnswerValue currentAnswer;
  final AnswerValue? submittedAnswer;
  final AnswerValue? revealedAnswer;
  final Color? revealedColor;
  final bool editable;
  final Map<String, AnswerValue>? otherPlayersAnswers;
  final String? currentPlayerAvatarUrl;
  final ValueChanged<AnswerValue>? onAnswerChanged;

  /// Lower bound of acceptable answer range (for survival mode highlighting)
  final AnswerValue? acceptableRangeLower;

  /// Upper bound of acceptable answer range (for survival mode highlighting)
  final AnswerValue? acceptableRangeUpper;

  @override
  State<AnswerAccuracyScale> createState() => _AnswerAccuracyScaleState();
}

class _AnswerAccuracyScaleState extends State<AnswerAccuracyScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool _isDragging = false; // Track active drag to prevent recursion
  AnswerValue?
      _lastEmittedValue; // Track last emitted value to prevent duplicates
  double? _lastSliderValue; // Track last slider value for haptic feedback

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
    // Skip external updates during active drag to prevent recursion
    if (_isDragging) {
      return;
    }

    if (widget.revealedAnswer != null && oldWidget.revealedAnswer == null) {
      _controller.forward(from: 0.0);
    } else if (widget.revealedAnswer == null &&
        oldWidget.revealedAnswer != null) {
      _controller.reset();
    }

    // Reset last emitted value if answer changed externally
    if (oldWidget.currentAnswer != widget.currentAnswer) {
      _lastEmittedValue = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getSliderValue(AnswerValue value) {
    if (value.number <= 0) return 0.0;

    final omPowers = {
      '': 0,
      'K': 3,
      'M': 6,
      'B': 9,
      'T': 12,
    };
    final exponent = omPowers[value.orderOfMagnitude] ?? 0;

    // Decompose number into local decade and fraction
    // number is 1..999
    // 1..10 -> local 0..1
    // 10..100 -> local 1..2
    // 100..1000 -> local 2..3

    double localLog;
    if (value.number < 10) {
      // 1 maps to 0.0, 10 maps to 1.0
      // v = 1 + 9 * fraction => fraction = (v - 1) / 9
      localLog = (value.number - 1) / 9.0;
    } else if (value.number < 100) {
      // 10 maps to 1.0, 100 maps to 2.0
      // v = 10 * (1 + 9 * fraction) => fraction = (v/10 - 1) / 9
      localLog = 1.0 + (value.number / 10.0 - 1) / 9.0;
    } else {
      // 100 maps to 2.0, 1000 maps to 3.0
      localLog = 2.0 + (value.number / 100.0 - 1) / 9.0;
    }

    return exponent + localLog;
  }

  String _formatAnswerText(AnswerValue value) {
    if (value.rawValue != null) {
      final double raw = value.rawValue!;
      // Check if out of bounds (same logic as decomposeNumber)
      const double maxDisplayable = 999e12;
      if (raw < 1 || raw > maxDisplayable) {
        // Use human-readable scientific notation (e.g., "6.2 × 10³⁰")
        return formatScientificNotation(raw);
      }
    }
    // Fallback to decomposed format (without unit since both answers have the same unit)
    return '${value.number} ${value.orderOfMagnitude}'.trim();
  }

  /// Convert x-position to slider value (0-15 scale)
  double _positionToSliderValue(double x, double width) {
    const padding = 12.0;
    final drawWidth = width - (padding * 2);
    final normalizedX = (x - padding).clamp(0.0, drawWidth);
    return (normalizedX / drawWidth) * 15.0;
  }

  /// Convert continuous slider value to AnswerValue with snapping
  /// Snaps to: 1, 2, ..., 9, 10, 20, ..., 90, 100, ...
  AnswerValue _sliderToAnswerValue(double sliderValue, String unit) {
    // Clamp to valid range
    final clampedSlider = sliderValue.clamp(0.0, 15.0);

    // Handle Max Value (15.0) explicitly to avoid wrap-around to 1T
    // 15.0 represents 1000 T mathematically in this scale, so we clamp to 999 T
    if (clampedSlider >= 15.0) {
      return AnswerValue(number: 999, orderOfMagnitude: 'T', unit: unit);
    }

    // Snap to nearest 1/9th
    // round(val * 9) / 9
    final snappedSlider = (clampedSlider * 9.0).round() / 9.0;

    // Handle 15.0 after snap as well
    if (snappedSlider >= 15.0) {
      return AnswerValue(number: 999, orderOfMagnitude: 'T', unit: unit);
    }

    // Determine global order of magnitude (0..15 range split into 3s)
    // 0..1, 1..2, 2..3 -> OM 0 ('')
    // 3..4, 4..5, 5..6 -> OM 1 ('K')
    final globalExponent = snappedSlider.floor();
    final omIndex =
        (globalExponent ~/ 3).clamp(0, orderOfMagnitudeSymbols.length - 1);
    final om = orderOfMagnitudeSymbols[omIndex];

    // Determine local power of 10 (0, 1, 2)
    final localExponent = globalExponent % 3;

    // Determine digit (1..10)
    // fraction = snapped - floor
    // digit = 1 + 9 * fraction
    final fraction = snappedSlider - globalExponent;
    // Round to handle floating point imprecision
    int digit = (1.0 + 9.0 * fraction).round();

    // Calculate final number
    int number = digit * math.pow(10, localExponent).toInt();

    // Handle wrap-around case where number becomes 1000 (next OM)
    // In our slider logic, 1000 of OM[i] is effectively 1 of OM[i+1]
    // The previous math handles this naturally if we strictly follow the slider:
    // 2.99 -> exponent 2, fraction ~1, digit 10. number = 10 * 100 = 1000.
    // 3.00 -> exponent 3, fraction 0, digit 1. number = 1 * 1 = 1. OM upgraded.
    // Since 1000 = 1K, we prefer the canonical form 1K (which is 3.00).
    // However, if we get 1000 here, we should probably clamp or normalize.
    // Given the widget uses standard AnswerValue, 1000 is valid but usually displayed as 1K.
    // Let's normalize 1000 to 1 of next OM if possible, or just clamp to 999
    // if strictly enforcing 1-999 range.
    // But the slider is continuous. 3.0 is 1K. 2.99... (1000) is 1K.
    // If the snap hits exactly the boundary, it will be x.0 which gives digit 1, next OM.
    // The only case giving 1000 is if we snap to the very top of a decade range
    // but stay in the lower decade floor?
    // No, if fraction is 1.0, it means we are at the next integer.
    // floor(3.0) is 3, fraction 0.
    // floor(2.999) is 2, fraction 0.999.
    // If we snapped 2.99 to 3.0, floor is 3.
    // So distinct cases.
    // Check digit 10 case:
    // If snappedSlider = 2.999 -> rounds to 3.0? No, 2.888.. (8/9) -> 9. 2 + 8/9.
    // Digit = 1 + 8 = 9. Number = 900.
    // The 10th step (9/9) is the start of the next integer interval.
    // So strictly digit will be 1..9 ?
    // range of k is 0..8?
    // Slider N + k/9.
    // If k=0 -> 1.
    // If k=8 -> 1 + 8 = 9.
    // What about 10?
    // 10 is the start of the next segment.
    // So 1, 2...9. Next is 10 (which is 1 of next decade).
    // So digit should be 1..9.

    // But wait, the user said "dots on 2,3,4,...,9,20,30,...,90".
    // 10, 20... are the START of the intervals.
    // range ]1, 2]...
    // My math: Slider N maps to 1 * 10^N.
    // Slider N + 1 maps to 10 * 10^N.
    // Slider N + 1/9 maps to 2 * 10^N.

    return AnswerValue(number: number, orderOfMagnitude: om, unit: unit);
  }

  /// Commit a position immediately (for taps and drag start).
  void _commitPosition(double x, double width) {
    // Only allow interaction when editable and callback is provided
    if (!widget.editable || widget.onAnswerChanged == null) {
      return;
    }

    // Don't allow interaction during reveal animation
    if (widget.revealedAnswer != null) {
      return;
    }

    final sliderValue = _positionToSliderValue(x, width);
    final currentUnit = widget.currentAnswer.unit;
    final newAnswer = _sliderToAnswerValue(sliderValue, currentUnit);

    _triggerHapticIfCrossedTick(sliderValue);

    if (_lastEmittedValue == newAnswer) {
      return;
    }

    _lastEmittedValue = newAnswer;
    widget.onAnswerChanged!(newAnswer);
  }

  /// Trigger haptic feedback when crossing an order-of-magnitude tick.
  void _triggerHapticIfCrossedTick(double sliderValue) {
    if (_lastSliderValue != null) {
      final prevOM = _lastSliderValue!.floor();
      final currOM = sliderValue.floor();
      if (prevOM != currOM) {
        FeedbackService.instance.selectionChange();
      }
    }
    _lastSliderValue = sliderValue;
  }

  Widget _buildAvatar(String url, AppTheme appTheme) {
    return ClipOval(
      child: Container(
        width: 12, // Small size for text box
        height: 12,
        color: appTheme.bgLight,
        child: url.toLowerCase().endsWith('.svg')
            ? Padding(
                padding: const EdgeInsets.all(1.0),
                child: SvgPicture.network(
                  url,
                  fit: BoxFit.contain,
                  placeholderBuilder: (context) =>
                      Container(color: appTheme.bgLight),
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: appTheme.bgLight);
                },
              ),
      ),
    );
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

    final userLogValue = _getSliderValue(userAnswer);

    final userTextStyle = AppFont.secondaryTextStyle(
      context,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: appTheme.text,
    );

    final correctTextStyle = AppFont.secondaryTextStyle(
      context,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: appTheme.bgLight,
    );

    final labelTextStyle = AppFont.secondaryTextStyle(
      context,
      fontSize: 10,
      fontWeight: FontWeight.w300,
      color: appTheme.border.withAlpha(160),
    );

    // Clip correct log value to 0..18 range for the circle position
    // But we use the raw value for the text
    double? correctLogValue;
    if (widget.revealedAnswer != null) {
      final rawLog = _getSliderValue(widget.revealedAnswer!);
      correctLogValue = rawLog.clamp(0.0, 15.0);
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
                final userX = padding + (userLogValue / 15.0) * drawWidth;
                final correctX = padding + (correctLogValue / 15.0) * drawWidth;
                currentCorrectX = userX + (correctX - userX) * _animation.value;
              }

              // Wrap with GestureDetector for interactive input
              final interactiveWidget = Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: Size(w, 48),
                    painter: ScalePainter(
                      userLogValue: userLogValue,
                      correctLogValue: correctLogValue,
                      revealProgress: _animation.value,
                      appTheme: appTheme,
                      revealedColor: widget.revealedColor,
                      labelTextStyle: labelTextStyle,
                      otherPlayersLogValues: widget.otherPlayersAnswers?.map(
                              (id, ans) =>
                                  MapEntry(id, _getSliderValue(ans))) ??
                          {},
                      acceptableRangeLower: widget.acceptableRangeLower != null
                          ? _getSliderValue(widget.acceptableRangeLower!)
                          : null,
                      acceptableRangeUpper: widget.acceptableRangeUpper != null
                          ? _getSliderValue(widget.acceptableRangeUpper!)
                          : null,
                    ),
                  ),
                  // Other players' text boxes moved to carousel in QuestionAnswerCard
                  // User Answer Text Box
                  Positioned(
                    left: padding + (userLogValue / 15.0) * drawWidth,
                    bottom:
                        38, // Position 8px above the scale (y=16, bottom=32)
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, 0),
                      child: AnimatedOpacity(
                        duration: _isDragging
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        opacity: _isDragging ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: appTheme.bgLight,
                            border:
                                Border.all(color: appTheme.bgLight, width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.currentPlayerAvatarUrl != null &&
                                  widget
                                      .currentPlayerAvatarUrl!.isNotEmpty) ...[
                                _buildAvatar(
                                    widget.currentPlayerAvatarUrl!, appTheme),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                _formatAnswerText(userAnswer),
                                style: userTextStyle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Correct Answer Text Box
                  if (currentCorrectX != null && widget.revealedAnswer != null)
                    Positioned(
                      left: currentCorrectX,
                      bottom: 38, // Position 8px above the scale
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
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: appTheme.primaryMuted.withAlpha(100),
                                    blurRadius: 2,
                                    offset: const Offset(0, 2),
                                  ),
                                ]),
                            child: Text(
                              _formatAnswerText(widget.revealedAnswer!),
                              style: correctTextStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
              // Add gesture detection if editable and callback provided
              if (widget.editable &&
                  widget.onAnswerChanged != null &&
                  widget.revealedAnswer == null) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final localX = details.localPosition.dx;
                    _commitPosition(localX, w);
                  },
                  onHorizontalDragStart: (details) {
                    setState(() {
                      _isDragging = true;
                    });
                    final localX = details.localPosition.dx;
                    _commitPosition(localX, w);
                  },
                  onHorizontalDragUpdate: (details) {
                    final localX = details.localPosition.dx;
                    _commitPosition(localX, w);
                  },
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  onHorizontalDragCancel: () {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  child: interactiveWidget,
                );
              }

              return interactiveWidget;
            },
          );
        },
      ),
    );
  }
}
