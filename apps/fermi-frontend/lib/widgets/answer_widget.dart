import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/widgets/digit_wheels.dart';
import 'package:fermi_frontend/widgets/om_label.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/utils/logger.dart';

/// Unified controller for the complete answer widget (digits + OM + unit)
class AnswerController {
  DigitWheelsController? _digitsController;
  OmLabelController? _omController;
  UnitTapeController? _unitController;
  void Function(
    AnswerValue start,
    AnswerValue target,
    Duration duration,
    Color color, {
    void Function(AnswerValue)? onProgress,
    void Function()? onComplete,
  })? _reveal;
  void Function()? _resetVisualState;
  AnswerValue Function()? _getCurrentValue;

  void _bind({
    required DigitWheelsController digits,
    required OmLabelController om,
    required UnitTapeController unit,
    required void Function(
      AnswerValue start,
      AnswerValue target,
      Duration duration,
      Color color, {
      void Function(AnswerValue)? onProgress,
      void Function()? onComplete,
    }) reveal,
    required void Function() resetVisualState,
    required AnswerValue Function() getCurrentValue,
  }) {
    _digitsController = digits;
    _omController = om;
    _unitController = unit;
    _reveal = reveal;
    _resetVisualState = resetVisualState;
    _getCurrentValue = getCurrentValue;
  }

  /// Get the current answer value
  AnswerValue get currentValue {
    final fn = _getCurrentValue;
    if (fn != null) return fn();
    return const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
  }

  /// Jump to a specific answer value instantly (no animation)
  Future<void> jumpTo(AnswerValue target) async {
    _digitsController?.jumpTo(target.number);
    _omController?.jumpTo(target.orderOfMagnitude);
    _unitController?.jumpTo(target.unit);
  }

  /// Animate to a specific answer value
  Future<void> animateTo(AnswerValue target, Duration duration) async {
    await _digitsController?.animateTo(target.number, duration);
    await _omController?.animateTo(target.orderOfMagnitude, duration);
    await _unitController?.animateTo(target.unit, duration);
  }

  /// Reveal the correct answer with score-based color
  Future<void> reveal(
    AnswerValue start,
    AnswerValue target,
    Duration duration,
    Color color, {
    void Function(AnswerValue)? onProgress,
    void Function()? onComplete,
  }) async {
    AppLogger.debug(
        'AnswerController.reveal: start=$start, target=$target, duration=${duration.inMilliseconds}ms, color=$color');
    final fn = _reveal;
    if (fn != null) {
      AppLogger.debug(
          'AnswerController.reveal: Calling bound _reveal function');
      fn(start, target, duration, color,
          onProgress: onProgress, onComplete: onComplete);
      AppLogger.debug('AnswerController.reveal: _reveal function returned');
    } else {
      AppLogger.warning('AnswerController.reveal: _reveal function is null!');
    }
  }

  /// Reset visual state (clear reveal colors and reset tap indicators)
  void resetVisualState() {
    final fn = _resetVisualState;
    if (fn != null) fn();
  }

  /// Close any open bottom sheets (OM or Unit selectors)
  void closeBottomSheets() {
    _omController?.close();
    _unitController?.close();
    _digitsController?.clearFocus();
  }

  /// Request focus on the digit wheels (opens numpad)
  void requestFocus() {
    _digitsController?.requestFocus();
  }
}

/// Unified answer widget that combines digits, OM, and unit selection
/// Provides a clean API for managing the complete answer state
/// This widget is fully controlled - it displays the value prop and notifies parent of changes
class AnswerWidget extends StatefulWidget {
  const AnswerWidget({
    super.key,
    required this.value,
    required this.units,
    required this.unitOptions,
    required this.currentLocale,
    required this.onChanged,
    required this.onLocaleChanged,
    this.editable = true,
    this.controller,
    this.revealColor,
    required this.height,
    this.unitOptionsNotifier,
    this.digitsKey,
    this.omKey,
    this.allDigitsKey,
    this.unitKey,
    this.revealedAnswer,
    this.revealedColor,
  });

  final AnswerValue value; // Current display value (fully controlled)
  final List<String> units; // Available unit abbreviations
  final Map<String, String> unitOptions; // Full name -> abbreviation
  final String currentLocale; // 'US' or 'EU'
  final ValueChanged<AnswerValue> onChanged;
  final ValueChanged<String> onLocaleChanged;
  final bool editable;
  final AnswerController? controller;
  final Color? revealColor;
  final double height;
  final ValueNotifier<Map<String, String>>? unitOptionsNotifier;
  final Key? digitsKey;
  final Key? omKey;
  final Key? allDigitsKey;
  final Key? unitKey;
  final AnswerValue?
      revealedAnswer; // If provided, immediately reveal this answer
  final Color?
      revealedColor; // Color to use for immediate reveal (different from revealColor)

  @override
  State<AnswerWidget> createState() => _AnswerWidgetState();
}

class _AnswerWidgetState extends State<AnswerWidget> {
  static const int _numbersPerOm = 999;

  Color? _digitsOverrideColor;
  bool _isRevealing = false;

  final DigitWheelsController _digitsController = DigitWheelsController();
  final OmLabelController _omController = OmLabelController();
  final UnitTapeController _unitController = UnitTapeController();

  // Store revealed answer in widget state (like _digitsOverrideColor)
  AnswerValue? _revealedValue;

  // Get current display values from widget.value (fully controlled)
  int get _currentNumber => widget.value.number.clamp(1, _numbersPerOm);
  String get _currentOm => widget.value.orderOfMagnitude;
  String get _currentUnit => widget.value.unit;

  // Track if we're in the middle of a controller-managed animation
  // This prevents syncing controllers when value prop changes during animation
  bool _isControllerAnimating = false;

  // Track if controller animation is expected but hasn't started yet
  // This prevents applying props directly when controller will animate soon
  bool _isControllerAnimationPending = false;

  // Track if widget has been revealed - once revealed, preserve state unless explicitly cleared
  bool _hasBeenRevealed = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current value
    _digitsController.jumpTo(_currentNumber);
    _omController.jumpTo(_currentOm);
    if (_currentUnit.isNotEmpty) {
      _unitController.jumpTo(_currentUnit);
    }

    // Bind sub-controllers to parent controller
    widget.controller?._bind(
      digits: _digitsController,
      om: _omController,
      unit: _unitController,
      reveal: _revealToValue,
      resetVisualState: _resetVisualState,
      getCurrentValue: _currentValue,
    );

    // If revealed answer is provided, jump directly to revealed state (for review mode or non-current questions)
    // Only do this if controller is not bound AND widget is not editable
    if (widget.revealedAnswer != null &&
        widget.revealedColor != null &&
        widget.controller == null &&
        !widget.editable) {
      _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
    }
  }

  @override
  void didUpdateWidget(covariant AnswerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    AppLogger.debug(
        'AnswerWidget.didUpdateWidget: value=${widget.value}, revealedAnswer=${widget.revealedAnswer}, revealedColor=${widget.revealedColor}, controller=${widget.controller != null}, editable=${widget.editable}');
    AppLogger.debug(
        'AnswerWidget.didUpdateWidget: _isControllerAnimating=$_isControllerAnimating, _isControllerAnimationPending=$_isControllerAnimationPending, _hasBeenRevealed=$_hasBeenRevealed');

    // Check if revealed props are available (regardless of controller binding)
    final bool hasRevealedProps = widget.revealedAnswer != null &&
        widget.revealedColor != null &&
        !widget.editable;

    final bool hadRevealedProps = oldWidget.revealedAnswer != null &&
        oldWidget.revealedColor != null &&
        !oldWidget.editable;

    AppLogger.debug(
        'AnswerWidget.didUpdateWidget: hasRevealedProps=$hasRevealedProps, hadRevealedProps=$hadRevealedProps');

    // Handle controller binding changes
    if (oldWidget.controller != widget.controller) {
      final bool controllerUnbound =
          oldWidget.controller != null && widget.controller == null;
      final bool controllerBound =
          oldWidget.controller == null && widget.controller != null;

      if (controllerUnbound) {
        // Stop any ongoing animation when controller unbinds
        _isRevealing = false;
        _isControllerAnimating = false;

        // If question is revealed (via props or flag), preserve revealed state
        if (hasRevealedProps || _hasBeenRevealed) {
          // Apply revealed state if props are available
          if (hasRevealedProps) {
            _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
          }
          // If already revealed but props not available yet, keep revealed state
          // (props will arrive in next rebuild)
          return;
        } else {
          // Not revealed - reset visual state
          _resetVisualState();
          _syncControllersToValue();
        }
      }

      // Bind/rebind controller
      widget.controller?._bind(
        digits: _digitsController,
        om: _omController,
        unit: _unitController,
        reveal: _revealToValue,
        resetVisualState: _resetVisualState,
        getCurrentValue: _currentValue,
      );

      if (controllerBound) {
        // Controller was just bound - sync to value prop if not revealed
        if (!_hasBeenRevealed) {
          _syncControllersToValue();
        }
        return;
      }
    }

    // Priority 1: Handle revealed state (highest priority)
    if (hasRevealedProps) {
      if (widget.controller == null) {
        // Prop-controlled mode: Always apply to ensure consistency
        // Check if we need to update (props changed or not yet revealed)
        if (!_hasBeenRevealed ||
            _revealedValue != widget.revealedAnswer ||
            _digitsOverrideColor != widget.revealedColor) {
          _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
        }
        return;
      }

      // Controller is bound
      if (_isControllerAnimationPending || _isControllerAnimating) {
        // Animation in progress or pending - update color only
        AppLogger.debug(
            'AnswerWidget.didUpdateWidget: Priority 1 - Animation pending/animating, updating color only');
        if (_digitsOverrideColor != widget.revealedColor) {
          setState(() {
            _digitsOverrideColor = widget.revealedColor;
          });
        }
        return;
      }

      // If already revealed, ensure state is preserved
      if (_hasBeenRevealed && _revealedValue != null) {
        AppLogger.debug(
            'AnswerWidget.didUpdateWidget: Priority 1 - Already revealed, preserving state');
        if (_revealedValue != widget.revealedAnswer ||
            _digitsOverrideColor != widget.revealedColor) {
          _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
        }
        return;
      }

      // Mark animation as pending - controller will animate soon
      AppLogger.debug(
          'AnswerWidget.didUpdateWidget: Priority 1 - Setting _isControllerAnimationPending=true');
      setState(() {
        _isControllerAnimationPending = true;
      });
    }

    // Priority 2: Reset if revealed props were explicitly removed (not just temporarily missing)
    if (hadRevealedProps && !hasRevealedProps && !_hasBeenRevealed) {
      // Only reset if we weren't already revealed (preserve state across rebuilds)
      _resetVisualState();
      _syncControllersToValue();
      return;
    }

    // Priority 3: Controller manages state when bound (but don't override revealed state)
    if (widget.controller != null) {
      // If widget has been revealed, don't let controller reset it
      if (_hasBeenRevealed) {
        return;
      }
      // Controller handles updates for non-revealed state
      return;
    }

    // Priority 4: Sync to value prop (prop-controlled mode, non-revealed)
    if (!_hasBeenRevealed &&
        !_isRevealing &&
        !_isControllerAnimating &&
        !_isControllerAnimationPending &&
        oldWidget.value != widget.value) {
      _syncControllersToValue();
    }
  }

  /// Sync controllers to current widget.value
  void _syncControllersToValue() {
    // Don't sync if widget has been revealed (revealed state takes priority)
    if (_hasBeenRevealed) {
      // When revealed, ensure controllers match stored revealed value
      if (_revealedValue != null) {
        _digitsController
            .jumpTo(_revealedValue!.number.clamp(1, _numbersPerOm));
        _omController.jumpTo(_revealedValue!.orderOfMagnitude);
        if (_revealedValue!.unit.isNotEmpty) {
          _unitController.jumpTo(_revealedValue!.unit);
        }
      }
      return;
    }

    // For non-revealed state, sync from widget.value
    _digitsController.jumpTo(_currentNumber);
    _omController.jumpTo(_currentOm);
    if (_currentUnit.isNotEmpty) {
      _unitController.jumpTo(_currentUnit);
    }
  }

  /// Jump directly to revealed state without animation (for initial state setup)
  void _jumpToRevealedValue(AnswerValue target, Color color) {
    // Validate inputs
    if (target.number < 1 || target.number > _numbersPerOm) return;

    // Store revealed value in widget state FIRST
    _revealedValue = target;
    // Mark as revealed BEFORE setState to prevent race conditions
    _hasBeenRevealed = true;

    // Sync controllers to revealed value
    _digitsController.jumpTo(target.number.clamp(1, _numbersPerOm));
    _digitsController.setRevealEnabled(true);
    _omController.jumpTo(target.orderOfMagnitude);
    _omController.setRevealed(true);
    if (target.unit.isNotEmpty) {
      _unitController.jumpTo(target.unit);
      _unitController.setRevealed(true);
    }
    setState(() {
      _digitsOverrideColor = color;
    });
  }

  Future<void> _revealToValue(
    AnswerValue start,
    AnswerValue target,
    Duration duration,
    Color color, {
    void Function(AnswerValue)? onProgress,
    void Function()? onComplete,
  }) async {
    AppLogger.debug(
        'AnswerWidget._revealToValue START: start=$start, target=$target, duration=${duration.inMilliseconds}ms, color=$color');
    AppLogger.debug(
        'AnswerWidget._revealToValue: Current controller values - digits=${_digitsController.currentValue}');

    _isRevealing = true;
    _isControllerAnimating = true;
    _isControllerAnimationPending = false;

    // Jump controllers to explicit start value (eliminates ambiguity)
    AppLogger.debug(
        'AnswerWidget._revealToValue: Jumping controllers to start value');
    _digitsController.jumpTo(start.number.clamp(1, _numbersPerOm));
    _omController.jumpTo(start.orderOfMagnitude);
    if (start.unit.isNotEmpty) {
      _unitController.jumpTo(start.unit);
    }

    AppLogger.debug(
        'AnswerWidget._revealToValue: After jump - digits=${_digitsController.currentValue}');

    // Set colors and revealed state BEFORE starting animations so all visual changes start together
    AppLogger.debug(
        'AnswerWidget._revealToValue: Setting colors and revealed state at start');
    setState(() {
      _digitsOverrideColor = color;
    });

    // Start tap indicator fade animations for OM and unit with matching duration
    // (digits fade is handled inside _revealTo and uses the same duration)
    _omController.setRevealed(true, duration);
    if (target.unit.isNotEmpty) {
      _unitController.setRevealed(true, duration);
    }

    // Now animate from start to target - all animations run in parallel
    AppLogger.debug(
        'AnswerWidget._revealToValue: Starting all animations in parallel');

    final List<Future<void>> animations = [
      _digitsController.revealTo(
          target.number.clamp(1, _numbersPerOm), duration),
      _omController.animateTo(target.orderOfMagnitude, duration),
    ];

    if (target.unit.isNotEmpty) {
      animations.add(_unitController.animateTo(target.unit, duration));
    }

    // Wait for all animations to complete in parallel
    await Future.wait(animations);
    AppLogger.debug('AnswerWidget._revealToValue: All animations completed');

    AppLogger.debug('AnswerWidget._revealToValue: Setting final state');
    setState(() {
      _isRevealing = false;
      _isControllerAnimating = false;
      _hasBeenRevealed = true;
      _revealedValue = target;
    });

    if (onProgress != null) {
      onProgress(target);
    }
    AppLogger.debug('AnswerWidget._revealToValue: Calling onComplete callback');
    onComplete?.call();
    AppLogger.debug('AnswerWidget._revealToValue: COMPLETE');
  }

  void _resetVisualState() {
    // Don't reset if revealed props are available - preserve revealed state
    if (widget.revealedAnswer != null &&
        widget.revealedColor != null &&
        !widget.editable) {
      return;
    }

    setState(() {
      _digitsOverrideColor = null;
      _revealedValue = null; // Clear revealed value
      _isRevealing = false;
      _isControllerAnimating = false;
      _isControllerAnimationPending = false; // Clear pending flag
      _hasBeenRevealed = false; // Clear revealed flag
      _digitsController.setRevealEnabled(false);
      _omController.setRevealed(false);
      _unitController.setRevealed(false);
    });
  }

  AnswerValue _currentValue() {
    // Return current widget.value (fully controlled)
    return widget.value;
  }

  void _onDigitsChanged(int number) {
    if (_isRevealing) return;
    // Notify parent of change - parent will update value prop
    widget.onChanged(AnswerValue(
      number: number,
      orderOfMagnitude: _currentOm,
      unit: _currentUnit,
    ));
  }

  void _onOmChanged(String om) {
    if (_isRevealing) return;
    // Notify parent of change - parent will update value prop
    widget.onChanged(AnswerValue(
      number: _currentNumber,
      orderOfMagnitude: om,
      unit: _currentUnit,
    ));
  }

  void _onUnitChanged(String unit) {
    if (_isRevealing) return;
    // Notify parent of change - parent will update value prop
    widget.onChanged(AnswerValue(
      number: _currentNumber,
      orderOfMagnitude: _currentOm,
      unit: unit,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // If revealed, ensure controllers are synced (safety check)
    if (_hasBeenRevealed && _revealedValue != null && !_isRevealing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hasBeenRevealed && _revealedValue != null) {
          // Re-sync controllers if they somehow got out of sync
          _syncControllersToValue();
        }
      });
    }

    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final Color revealColor = widget.revealColor ?? appTheme.danger;

    // Fixed height for answer elements (digits, OM, unit)
    // The Container margin (1px all around) is part of the widget.height allocation
    // So we need to reduce elementHeight by the margin to fit inside
    const double containerMargin = 2.0; // 1px top + 1px bottom
    final double elementHeight = widget.height - containerMargin;

    return SizedBox(
      height: widget.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.all(1.0),
            constraints: BoxConstraints(
              maxHeight: widget.height - containerMargin,
            ),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Digit wheels
                // flex: 7 accounts for 3 digits + 24px internal spacing
                // to make each digit equal width to OM (flex: 2) and unit (flex: 2)
                Expanded(
                  flex: 7,
                  child: DigitWheels(
                    controller: _digitsController,
                    initialValue: _currentNumber,
                    height: elementHeight,
                    itemExtent: elementHeight,
                    enabled: widget.editable,
                    borderColor: Colors.transparent,
                    draggingBorderColor: appTheme.secondary,
                    focusedBorderColor: appTheme.secondary,
                    borderWidth: 2,
                    digitBackgroundColor: appTheme.bg,
                    digitTextStyle: AppFont.secondaryTextStyle(
                      context,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: appTheme.text,
                      decoration: TextDecoration.none,
                    ),
                    revealDigitTextStyle: AppFont.secondaryTextStyle(
                      context,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: _digitsOverrideColor ?? revealColor,
                      decoration: TextDecoration.none,
                    ),
                    focusedDigitTextStyle: AppFont.secondaryTextStyle(
                      context,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: appTheme.secondary,
                      decoration: TextDecoration.none,
                    ),
                    onChanged: _onDigitsChanged,
                    onLastDigitComplete: () {
                      // Auto-focus OM label when last digit is entered
                      _omController.requestFocus();
                    },
                    middleWheelKey: widget.digitsKey,
                    allWheelsKey: widget.allDigitsKey,
                  ),
                ),
                const SizedBox(width: 12),
                // OM label
                Expanded(
                  flex: 2,
                  child: OmLabel(
                    key: widget.omKey,
                    initialValue: _currentOm,
                    editable: widget.editable,
                    revealColor: _digitsOverrideColor,
                    controller: _omController,
                    onChanged: _onOmChanged,
                    backgroundColor: appTheme.bg,
                    onBeforeOpen: () {
                      // Close any open numpad before opening OM selector
                      _digitsController.clearFocus();
                    },
                    onSelectorComplete: () {
                      // Auto-focus unit tape when OM selection completes
                      if (widget.units.isNotEmpty && widget.editable) {
                        _unitController.requestFocus();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Unit tape (always render area to preserve layout)
                Expanded(
                  flex: 2,
                  child: widget.units.isNotEmpty
                      ? UnitTape(
                          key: widget.unitKey,
                          units: widget.units,
                          unitOptions: widget.unitOptions,
                          initialValue: _currentUnit,
                          currentLocale: widget.currentLocale,
                          onUnitChanged: _onUnitChanged,
                          onLocaleChanged: widget.onLocaleChanged,
                          editable: widget.editable,
                          revealColor: _digitsOverrideColor,
                          controller: _unitController,
                          unitOptionsNotifier: widget.unitOptionsNotifier,
                          backgroundColor: appTheme.bg,
                          onBeforeOpen: () {
                            // Close any open numpad before opening unit selector
                            _digitsController.clearFocus();
                          },
                        )
                      : const SizedBox(), // Placeholder preserves layout
                ),
              ], // Close Row children
            ), // Close Row
          ), // Close outer Container
        ],
      ), // Close Column
    ); // Close SizedBox
  }
}
