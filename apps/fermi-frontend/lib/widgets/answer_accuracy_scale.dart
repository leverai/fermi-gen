import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
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
    this.otherPlayersAvatars,
    this.currentPlayerAvatarUrl,
    this.onAnswerChanged,
  });

  final AnswerValue currentAnswer;
  final AnswerValue? submittedAnswer;
  final AnswerValue? revealedAnswer;
  final Color? revealedColor;
  final bool editable;
  final Map<String, AnswerValue>? otherPlayersAnswers;
  final Map<String, String?>? otherPlayersAvatars;
  final String? currentPlayerAvatarUrl;
  final ValueChanged<AnswerValue>? onAnswerChanged;

  @override
  State<AnswerAccuracyScale> createState() => _AnswerAccuracyScaleState();
}

class _AnswerAccuracyScaleState extends State<AnswerAccuracyScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final Set<String> _visibleTextBoxes = <String>{}; // Track visible text boxes
  bool _isDragging = false; // Track active drag to prevent recursion
  AnswerValue?
      _lastEmittedValue; // Track last emitted value to prevent duplicates

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

  void _toggleTextBox(String playerId) {
    setState(() {
      if (_visibleTextBoxes.contains(playerId)) {
        _visibleTextBoxes.remove(playerId);
      } else {
        _visibleTextBoxes.add(playerId);
      }
    });
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
      const double maxDisplayable = 999e12;
      if (raw < 1 || raw > maxDisplayable) {
        // Use scientific notation
        // Remove trailing zeros and + sign if preferred, but standard is fine
        return raw.toStringAsExponential(2);
      }
    }
    // Fallback to decomposed format (without unit since both answers have the same unit)
    return '${value.number} ${value.orderOfMagnitude}'.trim();
  }

  /// Convert x-position to log value (0-18 scale)
  double _positionToLogValue(double x, double width) {
    const padding = 12.0;
    final drawWidth = width - (padding * 2);
    final normalizedX = (x - padding).clamp(0.0, drawWidth);
    return (normalizedX / drawWidth) * 15.0;
  }

  /// Convert continuous log value to AnswerValue
  /// Allows any integer from 1-999 within each order of magnitude.
  /// logValue 0-3: number 1-999, om ''
  /// logValue 3-6: number 1-999, om 'K'
  /// logValue 6-9: number 1-999, om 'M'
  /// etc.
  AnswerValue _logToAnswerValue(double logValue, String unit) {
    // Clamp log value to valid range
    final clampedLog = logValue.clamp(0.0, 15.0);

    // Determine which OM bucket (every 3 log units = one OM level)
    final omIndex =
        (clampedLog / 3.0).floor().clamp(0, orderOfMagnitudeSymbols.length - 1);
    final om = orderOfMagnitudeSymbols[omIndex];

    // Calculate the number within this OM range
    // logValue within OM: 0-3 for '', 3-6 for 'K', etc.
    final logWithinOM = clampedLog - (omIndex * 3.0);

    // Convert log within OM to number: 10^logWithinOM
    // logWithinOM = 0 → number = 1
    // logWithinOM = 1 → number = 10
    // logWithinOM = 2 → number = 100
    // logWithinOM = 2.5 → number = 316
    final rawNumber = math.pow(10, logWithinOM);

    // Round to nearest integer and clamp to 1-999
    int number = rawNumber.round().clamp(1, 999);

    // Edge case: if we're at or very close to the next OM boundary,
    // the number might compute to 1000. Clamp it back.
    if (number >= 1000) {
      number = 999;
    }

    // Edge case: ensure minimum value is 1
    if (clampedLog == 0 && number < 1) {
      number = 1;
    }

    return AnswerValue(number: number, orderOfMagnitude: om, unit: unit);
  }

  /// Convert AnswerValue back to log value (for positioning)
  double _answerValueToLogValue(AnswerValue value) {
    final exponent = orderOfMagnitudePowers[value.orderOfMagnitude] ?? 0;
    // log10(number). number is 1..999.
    final logNum = value.number > 0 ? math.log(value.number) / math.ln10 : 0.0;
    return exponent + logNum;
  }

  /// Handle tap/drag gesture to update answer
  void _handlePositionUpdate(double x, double width) {
    // Only allow interaction when editable and callback is provided
    if (!widget.editable || widget.onAnswerChanged == null) {
      return;
    }

    // Don't allow interaction during reveal animation
    if (widget.revealedAnswer != null) {
      return;
    }

    // Convert position to answer value (continuous, no snapping)
    final logValue = _positionToLogValue(x, width);
    final currentUnit = widget.currentAnswer.unit;
    final newAnswer = _logToAnswerValue(logValue, currentUnit);

    // Prevent duplicate callbacks
    if (_lastEmittedValue == newAnswer) {
      return;
    }

    _lastEmittedValue = newAnswer;
    widget.onAnswerChanged!(newAnswer);
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
                      otherPlayersLogValues: widget.otherPlayersAnswers?.map(
                              (id, ans) => MapEntry(id, _getLogValue(ans))) ??
                          {},
                      otherPlayersAvatars: widget.otherPlayersAvatars ?? {},
                    ),
                  ),
                  // Current Player's Avatar Overlay (full opacity)
                  if (widget.currentPlayerAvatarUrl != null &&
                      widget.currentPlayerAvatarUrl!.isNotEmpty)
                    Positioned(
                      left: padding + (userLogValue / 15.0) * drawWidth - 8,
                      top: 24 - 8,
                      child: ClipOval(
                        child: Container(
                          width: 16,
                          height: 16,
                          color: appTheme.bgLight,
                          child: widget.currentPlayerAvatarUrl!
                                  .toLowerCase()
                                  .endsWith('.svg')
                              ? Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: SvgPicture.network(
                                    widget.currentPlayerAvatarUrl!,
                                    fit: BoxFit.contain,
                                    placeholderBuilder: (context) =>
                                        Container(color: appTheme.bgLight),
                                  ),
                                )
                              : Image.network(
                                  widget.currentPlayerAvatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(color: appTheme.bgLight);
                                  },
                                ),
                        ),
                      ),
                    ),
                  // Other Players' Avatar Overlays (0.5 opacity)
                  if (widget.otherPlayersAnswers != null &&
                      widget.otherPlayersAvatars != null)
                    ...widget.otherPlayersAnswers!.entries.map((entry) {
                      final playerId = entry.key;
                      final answer = entry.value;
                      final avatarUrl = widget.otherPlayersAvatars![playerId];

                      // Skip if no avatar URL
                      if (avatarUrl == null || avatarUrl.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final logValue = _getLogValue(answer);
                      final clampedLogValue = logValue.clamp(0.0, 15.0);
                      final x = padding + (clampedLogValue / 15.0) * drawWidth;

                      return Positioned(
                        left: x - 8,
                        top: 24 - 8,
                        child: ClipOval(
                          child: Container(
                            width: 16,
                            height: 16,
                            color: appTheme.bgLight,
                            child: avatarUrl.toLowerCase().endsWith('.svg')
                                ? Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: SvgPicture.network(
                                      avatarUrl,
                                      fit: BoxFit.contain,
                                      placeholderBuilder: (context) =>
                                          Container(color: appTheme.bgLight),
                                    ),
                                  )
                                : Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(color: appTheme.bgLight);
                                    },
                                  ),
                          ),
                        ),
                      );
                    }),
                  // Other Players' Circles (with tap handlers)
                  if (widget.otherPlayersAnswers != null)
                    ...widget.otherPlayersAnswers!.entries.map((entry) {
                      final playerId = entry.key;
                      final answer = entry.value;
                      final logValue = _getLogValue(answer);
                      final clampedLogValue = logValue.clamp(0.0, 15.0);
                      final x = padding + (clampedLogValue / 15.0) * drawWidth;

                      return Positioned(
                        left: x,
                        top: 24 -
                            8, // Center vertically (24 is half height, 8 is half indicator size)
                        child: GestureDetector(
                          onTap: () => _toggleTextBox(playerId),
                          child: Container(
                            width: 16,
                            height: 16,
                            color: Colors.transparent,
                          ),
                        ),
                      );
                    }),
                  // Other Players' Text Boxes
                  if (widget.otherPlayersAnswers != null)
                    ...widget.otherPlayersAnswers!.entries.map((entry) {
                      final playerId = entry.key;
                      final answer = entry.value;
                      final logValue = _getLogValue(answer);
                      final clampedLogValue = logValue.clamp(0.0, 15.0);
                      final x = padding + (clampedLogValue / 15.0) * drawWidth;
                      final isVisible = _visibleTextBoxes.contains(playerId);

                      return Positioned(
                        left: x,
                        top:
                            -14, // Position above the scale (same as user answer)
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, 0),
                          child: Opacity(
                            opacity: isVisible ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: !isVisible,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: appTheme.bgLight.withOpacity(0.9),
                                  border: Border.all(
                                      color: appTheme.border, width: 1),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          appTheme.shadowColor.withOpacity(0.1),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _formatAnswerText(answer),
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
                      );
                    }),
                  // User Answer Text Box
                  Positioned(
                    left: padding + (userLogValue / 15.0) * drawWidth,
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

              // Add gesture detection if editable and callback provided
              if (widget.editable &&
                  widget.onAnswerChanged != null &&
                  widget.revealedAnswer == null) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final localX = details.localPosition.dx;
                    _handlePositionUpdate(localX, w);
                  },
                  onHorizontalDragStart: (details) {
                    setState(() {
                      _isDragging = true;
                    });
                    final localX = details.localPosition.dx;
                    _handlePositionUpdate(localX, w);
                  },
                  onHorizontalDragUpdate: (details) {
                    final localX = details.localPosition.dx;
                    _handlePositionUpdate(localX, w);
                  },
                  onHorizontalDragEnd: (details) {
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
