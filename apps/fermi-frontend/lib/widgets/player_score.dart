import 'package:flutter/material.dart';

import 'dart:async';

import 'package:fermi_frontend/widgets/player_score_controller.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/models/rank.dart';

class PlayerScore extends StatefulWidget {
  const PlayerScore({
    super.key,
    required this.initialScore,
    this.controller,
    this.backgroundColor,
    this.incrementAmount,
    this.showIncrement = false,
    this.rank,
  });

  final int initialScore;
  final PlayerScoreController? controller;
  final Color? backgroundColor;
  final int? incrementAmount;
  final bool showIncrement;
  final Rank? rank;

  @override
  State<PlayerScore> createState() => _PlayerScoreState();
}

class _PlayerScoreState extends State<PlayerScore>
    with TickerProviderStateMixin {
  late List<int> _digits;
  final List<GlobalKey<_AnimatedDigitState>> _digitKeys = [];
  bool _isDisposed = false;
  late int _currentValue;
  late int _targetValue;
  bool _isAnimating = false;

  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialScore;
    _targetValue = widget.initialScore;
    _digits = _getDigits(_currentValue);
    _updateDigitKeys(_digits.length);
    if (widget.controller != null) {
      widget.controller!.increment = _enqueueDelta;
      widget.controller!.setScore = _enqueueSet;
    }

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    if (widget.rank != null) {
      _startShineLoop();
    }
  }

  void _startShineLoop() {
    if (!mounted || _isDisposed) return;
    _shineController.forward(from: 0.0).then((_) {
      if (!mounted || _isDisposed) return;
      Future.delayed(const Duration(milliseconds: 4200), () {
        if (mounted && !_isDisposed && widget.rank != null) {
          _startShineLoop();
        }
      });
    });
  }

  void _updateDigitKeys(int count) {
    if (_digitKeys.length == count) return;
    _digitKeys.clear();
    for (var i = 0; i < count; i++) {
      _digitKeys.add(GlobalKey<_AnimatedDigitState>());
    }
  }

  List<int> _getDigits(int score) {
    // Remove any non-digit characters (e.g., minus sign) and ensure at least 0
    final String digitsOnly = score.abs().toString();
    return digitsOnly.split('').map(int.parse).toList();
  }

  void _enqueueDelta(int amount) {
    if (!mounted || _isDisposed) return;
    _targetValue = _targetValue + amount;
    if (!_isAnimating) {
      _runAnimation();
    }
  }

  void _enqueueSet(int newValue) {
    if (!mounted || _isDisposed) return;
    _targetValue = newValue;
    if (!_isAnimating) {
      _runAnimation();
    }
  }

  Future<void> _runAnimation() async {
    if (!mounted || _isDisposed) return;
    _isAnimating = true;
    try {
      while (mounted && !_isDisposed && _currentValue != _targetValue) {
        final int start = _currentValue;
        final int end = _targetValue;

        final startDigits = _getDigits(start);
        final endDigits = _getDigits(end);
        final startDigitCount = startDigits.length;
        final endDigitCount = endDigits.length;

        // Determine the maximum digit count we'll need during this animation
        final maxDigitCount =
            startDigitCount > endDigitCount ? startDigitCount : endDigitCount;

        // Pad both start and end values to the max digit count
        final paddedStartDigits = start
            .toString()
            .padLeft(maxDigitCount, '0')
            .split('')
            .map(int.parse)
            .toList();
        final paddedEndDigits = end
            .toString()
            .padLeft(maxDigitCount, '0')
            .split('')
            .map(int.parse)
            .toList();

        // Expand digit count if needed, before animation starts
        if (maxDigitCount > _digits.length) {
          if (!mounted || _isDisposed) break;
          setState(() {
            _updateDigitKeys(maxDigitCount);
            _digits = paddedStartDigits;
          });
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || _isDisposed) break;

          // Wait for all digit keys to have valid states (handle rapid rebuilds)
          int retries = 0;
          while (retries < 10 && mounted && !_isDisposed) {
            bool allKeysReady = true;
            for (int i = 0; i < maxDigitCount; i++) {
              if (_digitKeys[i].currentState == null) {
                allKeysReady = false;
                break;
              }
            }
            if (allKeysReady) break;
            await Future.delayed(const Duration(milliseconds: 16));
            retries++;
          }
          if (!mounted || _isDisposed) break;
        }

        // Ensure we have enough keys (safety check for rapid updates)
        if (maxDigitCount > _digitKeys.length) {
          if (!mounted || _isDisposed) break;
          setState(() {
            _updateDigitKeys(maxDigitCount);
          });
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || _isDisposed) break;
        }

        // Start all digit animations simultaneously
        // Check that all keys have valid states before animating
        final animations = <Future<void>>[];
        bool hasNullStates = false;
        for (int i = 0; i < maxDigitCount; i++) {
          final from = paddedStartDigits[i];
          final to = paddedEndDigits[i];
          if (from != to) {
            final state = _digitKeys[i].currentState;
            if (state != null) {
              animations.add(state.animate(from, to));
            } else {
              hasNullStates = true;
              // If state is null, skip this digit (widget tree not ready yet)
              // The animation loop will retry on next iteration
            }
          }
        }

        // If any states were null, wait and retry on next loop iteration
        if (hasNullStates && _currentValue != _targetValue) {
          await Future.delayed(const Duration(milliseconds: 16));
          continue;
        }

        // If no animations to run but values differ, something went wrong - update directly
        if (animations.isEmpty && _currentValue != _targetValue) {
          // Fallback: update value directly without animation
          setState(() {
            _currentValue = _targetValue;
            _digits = _getDigits(_targetValue);
          });
          break;
        }

        // Wait for all animations to complete
        await Future.wait(animations);
        if (!mounted || _isDisposed) break;

        // Update the current value
        _currentValue = end;

        // Contract digits if the final value has fewer digits
        final finalDigitCount = endDigits.length;
        if (finalDigitCount < maxDigitCount) {
          if (!mounted || _isDisposed) break;
          setState(() {
            _digits = endDigits;
            _updateDigitKeys(finalDigitCount);
          });
        } else {
          setState(() {
            _digits = paddedEndDigits;
          });
        }

        // Loop will continue if _targetValue changed while animating
      }
    } finally {
      // Always reset _isAnimating, even if an exception occurred
      // This ensures future animations can start even after errors
      _isAnimating = false;
    }
  }

  @override
  void didUpdateWidget(covariant PlayerScore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rank != oldWidget.rank) {
      if (widget.rank != null) {
        if (!_shineController.isAnimating) {
          _shineController.reset();
          _startShineLoop();
        }
      } else {
        _shineController.stop();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _shineController.dispose();
    if (widget.controller != null) {
      widget.controller!.increment = null;
      widget.controller!.setScore = null;
    }
    super.dispose();
  }

  Color _getBackgroundColor(AppTheme appTheme) {
    if (widget.backgroundColor != null) return widget.backgroundColor!;
    // Always use static background (rank coloring moved to ring)
    return appTheme.bgLight;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final digitWidgets = <Widget>[];
    final numDigits = _digits.length;
    for (var i = 0; i < numDigits; i++) {
      digitWidgets.add(
        _AnimatedDigit(
          key: _digitKeys[i],
          initialDigit: _digits[i],
          textColor: appTheme.text,
        ),
      );
      final remainingDigits = numDigits - 1 - i;
      if (remainingDigits > 0 && remainingDigits % 3 == 0) {
        digitWidgets.add(_buildComma(appTheme.text));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: _getBackgroundColor(appTheme),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: appTheme.shadowColor,
            offset: const Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...digitWidgets,
                    if (widget.showIncrement && widget.incrementAmount != null)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: widget.showIncrement ? 1.0 : 0.0,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 300),
                          offset: widget.showIncrement
                              ? const Offset(0, 0)
                              : const Offset(-0.5, 0),
                          curve: Curves.easeOut,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              '+${_formatWithCommas(widget.incrementAmount!)}',
                              style: AppFont.secondaryTextStyle(
                                context,
                                fontWeight: FontWeight.w400,
                                fontSize: 10.0,
                                color: appTheme.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.rank != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedBuilder(
                      animation: _shineController,
                      builder: (context, _) {
                        final double progress = _shineController.value;
                        const double beamWidth = 24.0;
                        // Calculate total distance to travel (including beam width and some padding)
                        final double totalX =
                            constraints.maxWidth + beamWidth + 40;
                        final double totalY =
                            constraints.maxHeight + beamWidth + 40;

                        return Transform.translate(
                          offset: Offset(
                            constraints.maxWidth - (totalX * progress) + 20,
                            constraints.maxHeight - (totalY * progress) + 20,
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Transform.rotate(
                              angle: -0.785398, // -45 degrees
                              child: Container(
                                width: beamWidth,
                                height: constraints.maxHeight * 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.0),
                                      Colors.white.withOpacity(0.35),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComma(Color textColor) {
    return Text(
      ',',
      style: AppFont.secondaryTextStyle(
        context,
        fontWeight: FontWeight.w600,
        fontSize: 12.0,
        color: textColor,
      ),
    );
  }

  String _formatWithCommas(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

class _AnimatedDigit extends StatefulWidget {
  const _AnimatedDigit({
    super.key,
    required this.initialDigit,
    required this.textColor,
  });
  final int initialDigit;
  final Color textColor;

  @override
  State<_AnimatedDigit> createState() => _AnimatedDigitState();
}

class _AnimatedDigitState extends State<_AnimatedDigit> {
  late FixedExtentScrollController _scrollController;
  // Increased from 18.0 to 20.0 to accommodate text rendering variations
  // across different devices and prevent bottom clipping
  static const double _itemHeight = 16.0;
  static const int _middleIndex = 1000;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(
      initialItem: _middleIndex + widget.initialDigit,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> animate(int from, int to) {
    var currentItem = _scrollController.selectedItem;
    final currentItemOnDigit = currentItem % 10;
    if (currentItemOnDigit != from) {
      currentItem = (currentItem ~/ 10) * 10 + from;
    }
    final int targetItem;
    if (to > from) {
      targetItem = currentItem + (to - from);
    } else {
      targetItem = currentItem - (from - to);
    }
    return _scrollController.animateToItem(
      targetItem,
      duration: const Duration(milliseconds: 1500),
      curve: Curves.fastOutSlowIn,
    );
  }

  void setDigit(int to) {
    // Jump instantly to the desired digit without animation
    final int currentBase = _scrollController.selectedItem ~/ 10;
    final int targetItem = (currentBase * 10) + (to % 10);
    _scrollController.jumpToItem(targetItem);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = AppFont.secondaryTextStyle(
      context,
      fontWeight: FontWeight.w600,
      fontSize: 12.0,
      color: widget.textColor,
    );

    return SizedBox(
      height: _itemHeight,
      width: 7,
      child: ListWheelScrollView.useDelegate(
        controller: _scrollController,
        itemExtent: _itemHeight,
        physics: const NeverScrollableScrollPhysics(),
        perspective: 0.0001,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            return Center(
              child: Text(
                (index % 10).toString(),
                style: textStyle,
              ),
            );
          },
        ),
      ),
    );
  }
}
