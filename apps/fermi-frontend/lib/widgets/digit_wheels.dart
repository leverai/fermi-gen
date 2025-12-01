import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/keyboard_height_provider.dart';
import 'package:fermi_frontend/widgets/tap_indicator.dart';
import 'package:fermi_frontend/widgets/scroll_hint.dart';
import 'package:fermi_frontend/utils/logger.dart';

/// Custom scroll physics that prevents scrolling below a minimum index
class _MinIndexScrollPhysics extends FixedExtentScrollPhysics {
  final int minIndex;
  final double itemExtent;

  const _MinIndexScrollPhysics({
    super.parent,
    required this.minIndex,
    required this.itemExtent,
  });

  @override
  _MinIndexScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _MinIndexScrollPhysics(
      parent: buildParent(ancestor),
      minIndex: minIndex,
      itemExtent: itemExtent,
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final double minScrollExtent = minIndex * itemExtent;

    // Prevent scrolling below minIndex
    if (value < minScrollExtent) {
      return value - minScrollExtent;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

/// Controller to programmatically control a [DigitWheels] widget.
class DigitWheelsController {
  Future<void> Function(int value, Duration duration)? _animateTo;
  void Function(int value)? _jumpTo;
  int Function()? _readValue;
  Future<void> Function(int value, Duration duration)? _revealTo;
  void Function(bool enabled)? _setReveal;
  void Function()? _clearFocus;
  void Function()? _requestFocus;

  void _bind({
    required Future<void> Function(int value, Duration duration) animateTo,
    required void Function(int value) jumpTo,
    required int Function() readValue,
    required Future<void> Function(int value, Duration duration) revealTo,
    required void Function(bool enabled) setReveal,
    required void Function() clearFocus,
    required void Function() requestFocus,
  }) {
    _animateTo = animateTo;
    _jumpTo = jumpTo;
    _readValue = readValue;
    _revealTo = revealTo;
    _setReveal = setReveal;
    _clearFocus = clearFocus;
    _requestFocus = requestFocus;
  }

  Future<void> animateTo(int value, Duration duration) async {
    final fn = _animateTo;
    if (fn != null) await fn(value, duration);
  }

  void jumpTo(int value) {
    final fn = _jumpTo;
    if (fn != null) fn(value);
  }

  int get currentValue => _readValue?.call() ?? 1;

  Future<void> revealTo(int value, Duration duration) async {
    final fn = _revealTo;
    if (fn != null) await fn(value, duration);
  }

  void setRevealEnabled(bool enabled) {
    final fn = _setReveal;
    if (fn != null) fn(enabled);
  }

  /// Clear any active focus (hide keyboard).
  void clearFocus() {
    final fn = _clearFocus;
    if (fn != null) fn();
  }

  /// Request focus on the first digit (show keyboard).
  void requestFocus() {
    final fn = _requestFocus;
    if (fn != null) fn();
  }
}

/// A three-column digit selector (hundreds / tens / ones) using
/// ListWheelScrollView for physics-based momentum scrolling.
///
/// - Value range is 1..999 (000 is clamped to 001).
/// - Each digit scrolls independently for fast selection.
/// - Use [controller] to jump/animate the value (for reveal animations).
/// - Supports numpad input: tap a digit to focus it, then use keyboard 0-9.
class DigitWheels extends StatefulWidget {
  const DigitWheels({
    super.key,
    this.initialValue = 1,
    this.onChanged,
    this.height = 140,
    this.itemExtent = 36,
    this.controller,
    this.enabled = true,
    this.digitTextStyle,
    this.borderColor,
    this.borderWidth = 2.0,
    this.borderRadius = 0.0,
    this.revealDigitTextStyle,
    this.draggingBorderColor,
    this.focusedDigitTextStyle,
    this.focusedBorderColor,
    this.digitBackgroundColor,
    this.middleWheelKey,
    this.allWheelsKey,
    this.onLastDigitComplete,
  });

  final int initialValue; // 1..999
  final ValueChanged<int>? onChanged;
  final double height;
  final double itemExtent;
  final DigitWheelsController? controller;
  final bool enabled;
  final TextStyle? digitTextStyle;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final TextStyle? revealDigitTextStyle;
  final Color? draggingBorderColor;
  final TextStyle?
      focusedDigitTextStyle; // Style when digit is keyboard-focused
  final Color?
      focusedBorderColor; // Border color when digit is keyboard-focused
  final Color?
      digitBackgroundColor; // Background color for digit containers (fades on reveal)
  final Key? middleWheelKey; // Key for the middle (tens) digit wheel
  final Key?
      allWheelsKey; // Key for the parent container of all three digit wheels
  final VoidCallback?
      onLastDigitComplete; // Called when the last digit is entered via keyboard

  @override
  State<DigitWheels> createState() => _DigitWheelsState();
}

class _DigitWheelsState extends State<DigitWheels>
    with SingleTickerProviderStateMixin {
  late FixedExtentScrollController _hundreds;
  late FixedExtentScrollController _tens;
  late FixedExtentScrollController _ones;
  bool _revealed = false;
  bool _hundredsDragging = false;
  bool _tensDragging = false;
  bool _onesDragging = false;
  late AnimationController _borderOpacityController;
  late FocusNode _focusNode;
  late TextEditingController _textController;
  _WheelKind? _focusedWheel; // Track which wheel has keyboard focus
  bool _isProgrammaticScroll = false; // Track if scroll is from keyboard input
  double _lastKeyboardHeight =
      0; // Track keyboard height to detect native close button

  @override
  void initState() {
    super.initState();
    final value = _clampValue(widget.initialValue);
    final d = _decompose(value);
    _hundreds = FixedExtentScrollController(initialItem: d.hundreds);
    _tens = FixedExtentScrollController(initialItem: d.tens);
    _ones = FixedExtentScrollController(initialItem: d.ones);
    _focusNode = FocusNode();
    _textController = TextEditingController();
    _borderOpacityController = AnimationController(
      vsync: this,
      value: 1.0,
      upperBound: 1.0,
      lowerBound: 0.0,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    // Listen to focus changes to clear wheel selection when keyboard closes
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _focusedWheel != null) {
        // Use post-frame callback to ensure state update happens after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_focusNode.hasFocus) {
            setState(() {
              _focusedWheel = null;
            });
          }
        });
      }
    });

    widget.controller?._bind(
      animateTo: _animateTo,
      jumpTo: _jumpTo,
      readValue: _compose,
      revealTo: _revealTo,
      setReveal: _setReveal,
      clearFocus: _clearFocus,
      requestFocus: _requestFocus,
    );
  }

  @override
  void dispose() {
    _hundreds.dispose();
    _tens.dispose();
    _ones.dispose();
    _borderOpacityController.dispose();
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _clearFocus() {
    setState(() {
      _focusedWheel = null;
    });
    _focusNode.unfocus();
  }

  void _requestFocus() {
    if (!widget.enabled || _revealed) return;
    // Focus the first digit (hundreds)
    _onWheelTapped(_WheelKind.hundreds);
  }

  int _clampValue(int v) {
    final c = v.clamp(1, 999);
    return c;
  }

  _Digits _decompose(int v) {
    final int hundreds = (v ~/ 100) % 10;
    final int tens = (v ~/ 10) % 10;
    final int ones = v % 10;
    return _Digits(hundreds: hundreds, tens: tens, ones: ones);
  }

  int _compose() {
    int h = _hundreds.selectedItem;
    int t = _tens.selectedItem;
    int o = _ones.selectedItem;
    int val = h * 100 + t * 10 + o;
    if (val == 0) {
      val = 1; // clamp 000 → 001
      // Force ones wheel to show 1 visually when both hundreds and tens are 0
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ones.selectedItem == 0 && h == 0 && t == 0) {
          _ones.jumpToItem(1);
        }
      });
    }
    return val;
  }

  void _emitChanged() {
    final v = _compose();
    widget.onChanged?.call(v);
    // Trigger rebuild to update ones wheel's available options
    if (mounted) {
      setState(() {});
    }
  }

  void _jumpTo(int value) {
    final v = _clampValue(value);
    final d = _decompose(v);
    _hundreds.jumpToItem(d.hundreds);
    _tens.jumpToItem(d.tens);
    _ones.jumpToItem(d.ones);
    // Defer onChanged callback to after current build phase to prevent
    // "setState() called during build" errors when jumpTo is called from didUpdateWidget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _emitChanged();
      }
    });
  }

  Future<void> _animateTo(int value, Duration duration) async {
    final v = _clampValue(value);
    final d = _decompose(v);
    final current = _compose();
    AppLogger.debug(
        'DigitWheels._animateTo: value=$value, clamped=$v, current=$current, decomposed=hundreds=${d.hundreds}, tens=${d.tens}, ones=${d.ones}, duration=${duration.inMilliseconds}ms');
    AppLogger.debug(
        'DigitWheels._animateTo: Calling animateToItem on all wheels');
    await Future.wait([
      _hundreds.animateToItem(d.hundreds,
          duration: duration, curve: Curves.easeInOutCubic),
      _tens.animateToItem(d.tens,
          duration: duration, curve: Curves.easeInOutCubic),
      _ones.animateToItem(d.ones,
          duration: duration, curve: Curves.easeInOutCubic),
    ]);
    AppLogger.debug(
        'DigitWheels._animateTo: All animateToItem calls completed');
    // onChanged will be emitted from listeners below
  }

  Future<void> _revealTo(int value, Duration duration) async {
    AppLogger.debug(
        'DigitWheels._revealTo: value=$value, duration=${duration.inMilliseconds}ms, currentValue=${_compose()}');
    setState(() => _revealed = true);
    // Fade borders to transparent alongside the reveal animation.
    // Stop any existing animation and ensure controller starts at 1.0 (fully visible) before animating to 0.0
    _borderOpacityController.stop();
    _borderOpacityController.value = 1.0;
    _borderOpacityController.duration = duration;
    _borderOpacityController.animateTo(0.0, curve: Curves.easeInOutCubic);
    AppLogger.debug(
        'DigitWheels._revealTo: Calling _animateTo($value, $duration)');
    await _animateTo(value, duration);
    AppLogger.debug('DigitWheels._revealTo: _animateTo returned');
  }

  void _setReveal(bool enabled) {
    setState(() {
      _revealed = enabled;
      // Clear focus when revealing (answer is locked)
      if (enabled) {
        _focusedWheel = null;
        _focusNode.unfocus();
      }
    });
    if (enabled) {
      _borderOpacityController.animateTo(0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic);
    } else {
      _borderOpacityController.animateTo(1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic);
    }
  }

  void _onWheelTapped(_WheelKind kind) {
    if (!widget.enabled || _revealed) return;

    // Clear any stale focus state if keyboard was previously closed
    if (!_focusNode.hasFocus && _focusedWheel != null) {
      _focusedWheel = null;
    }

    setState(() {
      _focusedWheel = kind;
    });
    // Always request focus to show keyboard (handles re-tapping after manual close)
    _focusNode.requestFocus();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (!widget.enabled || _revealed) return;

    // Guard against null focusedWheel (shouldn't happen, but be defensive)
    final focused = _focusedWheel;
    if (focused == null) return;

    // Parse numeric keys (0-9) from both main keyboard and numpad
    int? digit;
    if (event.logicalKey == LogicalKeyboardKey.digit0 ||
        event.logicalKey == LogicalKeyboardKey.numpad0) {
      digit = 0;
    } else if (event.logicalKey == LogicalKeyboardKey.digit1 ||
        event.logicalKey == LogicalKeyboardKey.numpad1) {
      digit = 1;
    } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
        event.logicalKey == LogicalKeyboardKey.numpad2) {
      digit = 2;
    } else if (event.logicalKey == LogicalKeyboardKey.digit3 ||
        event.logicalKey == LogicalKeyboardKey.numpad3) {
      digit = 3;
    } else if (event.logicalKey == LogicalKeyboardKey.digit4 ||
        event.logicalKey == LogicalKeyboardKey.numpad4) {
      digit = 4;
    } else if (event.logicalKey == LogicalKeyboardKey.digit5 ||
        event.logicalKey == LogicalKeyboardKey.numpad5) {
      digit = 5;
    } else if (event.logicalKey == LogicalKeyboardKey.digit6 ||
        event.logicalKey == LogicalKeyboardKey.numpad6) {
      digit = 6;
    } else if (event.logicalKey == LogicalKeyboardKey.digit7 ||
        event.logicalKey == LogicalKeyboardKey.numpad7) {
      digit = 7;
    } else if (event.logicalKey == LogicalKeyboardKey.digit8 ||
        event.logicalKey == LogicalKeyboardKey.numpad8) {
      digit = 8;
    } else if (event.logicalKey == LogicalKeyboardKey.digit9 ||
        event.logicalKey == LogicalKeyboardKey.numpad9) {
      digit = 9;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      // ESC clears focus
      _clearFocus();
      return;
    }

    if (digit == null) return;
    _handleDigitInput(digit);
  }

  void _handleDigitInput(int digit) {
    if (!widget.enabled || _revealed) return;
    final focused = _focusedWheel;
    if (focused == null) return;

    // Update the focused wheel
    final controller = switch (focused) {
      _WheelKind.hundreds => _hundreds,
      _WheelKind.tens => _tens,
      _WheelKind.ones => _ones,
    };

    // Mark this as a programmatic scroll so it doesn't close the keyboard
    _isProgrammaticScroll = true;
    controller.jumpToItem(digit);
    // Reset flag after a short delay (scroll notification will have fired by then)
    Future.delayed(const Duration(milliseconds: 50), () {
      _isProgrammaticScroll = false;
    });

    _emitChanged();

    // Auto-advance to next wheel
    final nextWheel = switch (focused) {
      _WheelKind.hundreds => _WheelKind.tens,
      _WheelKind.tens => _WheelKind.ones,
      _WheelKind.ones => null, // Last digit entered, close keyboard
    };

    setState(() {
      _focusedWheel = nextWheel;
    });

    // Close keyboard after last digit and notify parent
    if (nextWheel == null) {
      _focusNode.unfocus();
      // Notify parent that all digits have been entered
      widget.onLastDigitComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled;

    // Monitor keyboard height to detect when user closes keyboard via native button
    // Use KeyboardHeightProvider which provides real keyboard height even when MediaQuery is overridden
    final keyboardHeight = KeyboardHeightProvider.of(context);

    if (_lastKeyboardHeight > 0 &&
        keyboardHeight == 0 &&
        _focusedWheel != null) {
      // Keyboard was closed (via native button), clear focus state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _focusedWheel = null;
          });
          _focusNode.unfocus();
        }
      });
    }
    _lastKeyboardHeight = keyboardHeight;

    return Stack(
      children: [
        // Main visible digit wheels
        Focus(
          focusNode: _focusNode,
          onKeyEvent: (node, event) {
            _handleKeyEvent(event);
            return KeyEventResult.handled;
          },
          child: SizedBox(
            height: widget.height,
            child: Row(
              key: widget.allWheelsKey,
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 1,
                  child: _buildWheel(
                      _hundreds, enabled, _WheelKind.hundreds, null),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildWheel(
                      _tens, enabled, _WheelKind.tens, widget.middleWheelKey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildWheel(_ones, enabled, _WheelKind.ones, null),
                ),
              ],
            ),
          ),
        ),
        // Invisible TextField to trigger mobile keyboard
        Positioned(
          left: -1000,
          top: -1000,
          child: SizedBox(
            width: 1,
            height: 1,
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                showCursor: false,
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (text) {
                  // Handle input from the text field (for mobile keyboard)
                  if (text.isEmpty) return;
                  final lastChar = text[text.length - 1];
                  final int? digit = int.tryParse(lastChar);
                  if (digit != null && digit >= 0 && digit <= 9) {
                    _handleDigitInput(digit);
                  }
                  // Clear the text field so we can detect the next input
                  _textController.clear();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWheel(FixedExtentScrollController controller, bool enabled,
      _WheelKind kind, Key? wheelKey) {
    // Only show the selected (center) digit by clipping the wheel's visible area
    // to a box with height equal to itemExtent.
    return GestureDetector(
      onTap: () => _onWheelTapped(kind),
      child: SizedBox(
        key: wheelKey,
        height: widget.height,
        child: Center(
          child: AnimatedBuilder(
            animation: _borderOpacityController,
            builder: (context, child) {
              final bool isFocused = _focusedWheel == kind;
              final bool dragging = switch (kind) {
                _WheelKind.hundreds => _hundredsDragging,
                _WheelKind.tens => _tensDragging,
                _WheelKind.ones => _onesDragging,
              };
              // Hide indicators when dragging or focused
              final double effectiveOpacity = (isFocused || dragging)
                  ? 0.0
                  : _borderOpacityController.value;

              return ScrollHint(
                opacity: effectiveOpacity,
                child: SizedBox(
                  height: widget.itemExtent,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: widget.digitBackgroundColor == null ||
                                  widget.digitBackgroundColor ==
                                      Colors.transparent
                              ? Colors.transparent
                              : widget.digitBackgroundColor!
                                  // ignore: deprecated_member_use
                                  .withOpacity(_borderOpacityController.value),
                          borderRadius:
                              BorderRadius.circular(widget.borderRadius),
                          border: Border.all(
                            color: _borderColorFor(kind, context),
                            width: widget.borderWidth,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(widget.borderRadius),
                          child: ClipRect(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n is ScrollStartNotification) {
                                  _setDragging(kind, true);
                                  // Clear focus when user starts scrolling manually
                                  // BUT NOT when scrolling is triggered programmatically (keyboard input)
                                  if (_focusedWheel == kind &&
                                      !_isProgrammaticScroll) {
                                    setState(() => _focusedWheel = null);
                                    _focusNode.unfocus();
                                  }
                                } else if (n is ScrollEndNotification) {
                                  _setDragging(kind, false);
                                  _emitChanged();
                                }
                                return false;
                              },
                              child: ListWheelScrollView.useDelegate(
                                controller: controller,
                                itemExtent: widget.itemExtent,
                                physics: enabled
                                    ? () {
                                        // Only apply special physics for ones wheel when both hundreds and tens are 0
                                        if (kind == _WheelKind.ones &&
                                            _hundreds.hasClients &&
                                            _tens.hasClients) {
                                          try {
                                            if (_hundreds.selectedItem == 0 &&
                                                _tens.selectedItem == 0) {
                                              return _MinIndexScrollPhysics(
                                                minIndex: 1,
                                                itemExtent: widget.itemExtent,
                                              );
                                            }
                                          } catch (_) {
                                            // Controllers not fully initialized yet
                                          }
                                        }
                                        return const FixedExtentScrollPhysics();
                                      }()
                                    : const NeverScrollableScrollPhysics(),
                                perspective: 0.003,
                                diameterRatio: 1.6,
                                onSelectedItemChanged: (_) => _emitChanged(),
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, index) {
                                    if (index < 0 || index > 9) return null;

                                    // Prevent selecting 0 on the ones wheel when hundreds and tens are also 0
                                    // This ensures minimum value is 001, not 000
                                    if (kind == _WheelKind.ones &&
                                        index == 0 &&
                                        _hundreds.hasClients &&
                                        _tens.hasClients) {
                                      try {
                                        if (_hundreds.selectedItem == 0 &&
                                            _tens.selectedItem == 0) {
                                          return null;
                                        }
                                      } catch (_) {
                                        // Controllers not fully initialized yet
                                      }
                                    }

                                    return Center(
                                      child: Text(
                                        index.toString(),
                                        style: _textStyleFor(kind, context),
                                      ),
                                    );
                                  },
                                  childCount: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Tap indicator line at bottom
                      TapIndicator(
                        opacity: effectiveOpacity,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  TextStyle _textStyleFor(_WheelKind kind, BuildContext context) {
    final bool isFocused = _focusedWheel == kind;

    // Priority: focused > revealed > dragging > default
    if (isFocused && !_revealed) {
      return widget.focusedDigitTextStyle ??
          widget.digitTextStyle ??
          AppFont.secondaryTextStyle(
            context,
            fontSize: 28,
            fontWeight: FontWeight.w300,
            color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            decoration: TextDecoration.none,
          );
    } else if (_revealed) {
      return widget.revealDigitTextStyle ??
          widget.digitTextStyle ??
          AppFont.secondaryTextStyle(
            context,
            fontSize: 28,
            fontWeight: FontWeight.w300,
            color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            decoration: TextDecoration.none,
          );
    } else {
      return widget.digitTextStyle ??
          AppFont.secondaryTextStyle(
            context,
            fontSize: 28,
            fontWeight: FontWeight.w300,
            color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            decoration: TextDecoration.none,
          );
    }
  }

  void _setDragging(_WheelKind kind, bool value) {
    setState(() {
      switch (kind) {
        case _WheelKind.hundreds:
          _hundredsDragging = value;
          break;
        case _WheelKind.tens:
          _tensDragging = value;
          break;
        case _WheelKind.ones:
          _onesDragging = value;
          break;
      }
    });
  }

  Color _borderColorFor(_WheelKind kind, BuildContext context) {
    final bool isFocused = _focusedWheel == kind;
    final bool dragging = switch (kind) {
      _WheelKind.hundreds => _hundredsDragging,
      _WheelKind.tens => _tensDragging,
      _WheelKind.ones => _onesDragging,
    };

    // Priority: focused > dragging > default
    final Color base;
    if (isFocused && !_revealed) {
      base = widget.focusedBorderColor ??
          widget.draggingBorderColor ??
          widget.borderColor ??
          (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black);
    } else if (dragging) {
      base = widget.draggingBorderColor ??
          widget.borderColor ??
          (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black);
    } else {
      base = widget.borderColor ??
          (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black);
    }

    // Fade to transparent when revealing; preserve provided base alpha (e.g., P30)
    final double opacity = _borderOpacityController.value;
    // ignore: deprecated_member_use
    return base.withOpacity((base.opacity) * opacity);
  }
}

class _Digits {
  final int hundreds;
  final int tens;
  final int ones;
  const _Digits(
      {required this.hundreds, required this.tens, required this.ones});
}

enum _WheelKind { hundreds, tens, ones }
