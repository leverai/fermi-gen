import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'string_wheel.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/tap_indicator.dart';
import 'package:fermi_frontend/widgets/string_tape.dart';
import 'package:fermi_frontend/widgets/selector_widget.dart';
import 'package:fermi_frontend/widgets/scroll_hint.dart';
import 'package:fermi_frontend/widgets/unit_system_switch.dart';
import 'package:fermi_frontend/utils/logger.dart';

class UnitTapeController {
  void Function(String value)? _jumpTo;
  Future<void> Function(String value, Duration duration)? _animateTo;
  void Function()? _requestFocus;
  void Function(bool revealed, Duration? duration)? _setRevealed;
  void Function()? _close;

  void _bind({
    required void Function(String value) jumpTo,
    required Future<void> Function(String value, Duration duration) animateTo,
    required void Function() requestFocus,
    required void Function(bool revealed, Duration? duration) setRevealed,
    required void Function() close,
  }) {
    _jumpTo = jumpTo;
    _animateTo = animateTo;
    _requestFocus = requestFocus;
    _setRevealed = setRevealed;
    _close = close;
  }

  void jumpTo(String value) {
    final fn = _jumpTo;
    if (fn != null) fn(value);
  }

  Future<void> animateTo(String value, Duration duration) async {
    final fn = _animateTo;
    if (fn != null) await fn(value, duration);
  }

  void requestFocus() {
    final fn = _requestFocus;
    if (fn != null) fn();
  }

  void setRevealed(bool revealed, [Duration? duration]) {
    final fn = _setRevealed;
    if (fn != null) fn(revealed, duration);
  }

  /// Close the unit selector if it's open
  void close() {
    final fn = _close;
    if (fn != null) fn();
  }
}

class UnitTape extends StatefulWidget {
  const UnitTape({
    super.key,
    required this.units,
    required this.unitOptions,
    required this.initialValue,
    required this.currentLocale,
    required this.onUnitChanged,
    required this.onLocaleChanged,
    this.editable = false,
    this.revealColor,
    this.controller,
    this.unitOptionsNotifier,
    this.onBeforeOpen,
    this.backgroundColor,
  });

  final List<String> units; // Available unit abbreviations
  final Map<String, String> unitOptions; // Full name -> abbreviation
  final String initialValue; // Initial unit abbreviation
  final String currentLocale; // 'US' or 'EU'
  final ValueChanged<String> onUnitChanged;
  final ValueChanged<String> onLocaleChanged;
  final bool editable;
  final Color? revealColor; // Color to use during reveal (score-based)
  final UnitTapeController? controller;
  final ValueNotifier<Map<String, String>>?
      unitOptionsNotifier; // Optional external notifier
  final VoidCallback?
      onBeforeOpen; // Called before selector opens (to close other inputs)
  final Color?
      backgroundColor; // Background color that fades to transparent when revealed

  @override
  State<UnitTape> createState() => _UnitTapeState();
}

class _UnitTapeState extends State<UnitTape>
    with SingleTickerProviderStateMixin {
  final StringWheelController _wheel = StringWheelController();
  String? _current;
  bool _isFocused = false;
  bool _bottomSheetOpen = false;
  final ValueNotifier<Map<String, String>> _unitOptionsNotifier =
      ValueNotifier<Map<String, String>>({});
  late final AnimationController _indicatorFadeController;
  bool _isDragging = false; // Track StringWheel dragging state

  ValueNotifier<Map<String, String>> get _effectiveNotifier =>
      widget.unitOptionsNotifier ?? _unitOptionsNotifier;

  @override
  void initState() {
    super.initState();
    // Initialize indicator fade controller (visible by default)
    _indicatorFadeController = AnimationController(
      vsync: this,
      value: 1.0,
      upperBound: 1.0,
      lowerBound: 0.0,
      duration: const Duration(milliseconds: 600),
    );

    // If initialValue is empty, default to first unit in the list
    _current = widget.initialValue.isNotEmpty
        ? widget.initialValue
        : (widget.units.isNotEmpty ? widget.units[0] : '');
    // Only use internal notifier if no external one provided
    if (widget.unitOptionsNotifier == null) {
      _unitOptionsNotifier.value = widget.unitOptions;
    }

    widget.controller?._bind(
      jumpTo: (v) {
        setState(() => _current = v);
        _wheel.jumpTo(v);
        // Defer onUnitChanged callback to after current build phase to prevent
        // "setState() called during build" errors when jumpTo is called from didUpdateWidget
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onUnitChanged(v);
          }
        });
      },
      animateTo: (v, d) async {
        AppLogger.debug(
            'UnitTape.animateTo: value=$v, duration=${d.inMilliseconds}ms, current=$_current');
        setState(() => _current = v);
        await _wheel.animateTo(v, d);
        AppLogger.debug('UnitTape.animateTo: _wheel.animateTo returned');
      },
      requestFocus: _requestFocus,
      setRevealed: (r, duration) {
        if (r) {
          // Fade out indicator when revealing - use provided duration or default to 600ms
          _indicatorFadeController.animateTo(0.0,
              duration: duration ?? const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic);
        } else {
          // Fade in indicator when resetting
          _indicatorFadeController.animateTo(1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOutCubic);
        }
      },
      close: _closeUnitSelector,
    );

    // Notify parent of initial unit value to sync state on first render
    // This handles the case where UnitTape is conditionally rendered after units load
    if (_current != null && _current!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onUnitChanged(_current!);
      });
    }
  }

  @override
  void dispose() {
    _indicatorFadeController.dispose();
    // Only dispose internal notifier
    if (widget.unitOptionsNotifier == null) {
      _unitOptionsNotifier.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UnitTape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      widget.controller?._bind(
        jumpTo: (v) {
          setState(() => _current = v);
          _wheel.jumpTo(v);
          // Defer onUnitChanged callback to after current build phase to prevent
          // "setState() called during build" errors when jumpTo is called from didUpdateWidget
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onUnitChanged(v);
            }
          });
        },
        animateTo: (v, d) async {
          setState(() => _current = v);
          await _wheel.animateTo(v, d);
        },
        requestFocus: _requestFocus,
        setRevealed: (r, duration) {
          if (r) {
            // Fade out indicator when revealing - use provided duration or default to 600ms
            _indicatorFadeController.animateTo(0.0,
                duration: duration ?? const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic);
          } else {
            // Fade in indicator when resetting
            _indicatorFadeController.animateTo(1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic);
          }
        },
        close: _closeUnitSelector,
      );
    }
    // Update internal notifier when unitOptions change (only if using internal notifier)
    // Defer to post-frame to prevent "setState() called during build" errors
    // when ValueListenableBuilder listeners trigger during widget tree rebuild
    if (widget.unitOptionsNotifier == null &&
        oldWidget.unitOptions != widget.unitOptions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _unitOptionsNotifier.value = widget.unitOptions;
        }
      });
    }
    // Close the bottom sheet if widget becomes non-editable (e.g., deadline reached)
    if (oldWidget.editable && !widget.editable) {
      _closeUnitSelector();
    }
  }

  void _requestFocus() {
    if (!widget.editable) return;
    _showUnitSelector();
  }

  void _showUnitSelector() {
    if (!widget.editable) return;
    if (_bottomSheetOpen) return; // Prevent multiple bottom sheets

    // Notify parent before opening so it can close other inputs (e.g., numpad)
    widget.onBeforeOpen?.call();

    // Ensure _current matches what's actually displayed
    // If empty, use first unit in list (matching StringWheel behavior)
    if (_current == null || _current!.isEmpty) {
      _current = widget.units.isNotEmpty ? widget.units[0] : '';
    }

    setState(() {
      _isFocused = true;
      _bottomSheetOpen = true;
    });

    // Capture initial values but allow updates through callbacks
    String currentLocale = widget.currentLocale;
    final GlobalKey sheetKey = GlobalKey();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      isDismissible: true,
      enableDrag: true,
      builder: (modalContext) {
        final appTheme =
            Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

        return StatefulBuilder(
          builder: (context, setModalState) {
            return ValueListenableBuilder<Map<String, String>>(
              valueListenable: _effectiveNotifier,
              builder: (context, unitOptionsMap, child) {
                // Build fresh options from the latest unitOptions
                final List<SelectorOption> options = unitOptionsMap.entries
                    .map((e) => SelectorOption(label: e.key, value: e.value))
                    .toList();

                // Check if current value exists in new options
                String? currentValue =
                    _current?.isNotEmpty == true ? _current : null;
                final bool currentExistsInOptions = currentValue != null &&
                    options.any((opt) => opt.value == currentValue);

                // If current value doesn't exist in new options (e.g., after locale change),
                // default to first option
                if (!currentExistsInOptions && options.isNotEmpty) {
                  currentValue = options[0].value;
                  // Update _current to match
                  if (mounted) {
                    Future.microtask(() {
                      setModalState(() {
                        _current = currentValue;
                      });
                      _wheel.jumpTo(currentValue!);
                      widget.onUnitChanged(currentValue);
                    });
                  }
                }

                return _UnitSelectorSheet(
                  key: sheetKey,
                  appTheme: appTheme,
                  currentLocale: currentLocale,
                  options: options,
                  selectedUnit: currentValue,
                  onLocaleChanged: (newLocale) {
                    // Update local state and trigger modal rebuild
                    setModalState(() {
                      currentLocale = newLocale;
                    });
                    // Notify parent
                    widget.onLocaleChanged(newLocale);
                  },
                  onCenteredValueChanged: (value) {
                    // Update widget value in real-time as wheel scrolls
                    if (mounted) {
                      setModalState(() {
                        _current = value;
                      });
                      _wheel.jumpTo(value);
                      widget.onUnitChanged(value);
                    }
                  },
                  onUnitSelected: (value) {
                    if (mounted && value != null) {
                      // Update modal state first to show visual feedback
                      setModalState(() {
                        _current = value;
                      });
                      _wheel.jumpTo(value);
                      widget.onUnitChanged(value);
                      // Delay closing to allow visual feedback
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      });
                    }
                  },
                );
              },
            );
          },
        );
      },
    ).then((_) {
      // Reset focus state first
      if (mounted) {
        setState(() {
          _isFocused = false;
          _bottomSheetOpen = false;
        });
        // Only update local state - no focus management needed as this uses a modal
        // bottom sheet, not keyboard input.
      }
    });

    // No focus management needed - this uses a modal bottom sheet, not keyboard input.
  }

  void _closeUnitSelector() {
    if (_bottomSheetOpen && mounted) {
      Navigator.of(context).pop();
      // State will be reset by the .then() callback in _showUnitSelector
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure _current matches what StringWheel displays
    _current ??= widget.initialValue.isNotEmpty
        ? widget.initialValue
        : (widget.units.isNotEmpty ? widget.units[0] : '');
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Determine colors based on focus and dragging state
    final Color textColor = (_isFocused || _isDragging)
        ? appTheme.secondary
        : (widget.revealColor ?? appTheme.text);
    const Color borderColor = Colors.transparent;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: GestureDetector(
        onTap: widget.editable ? _showUnitSelector : null,
        child: AnimatedBuilder(
          animation: _indicatorFadeController,
          builder: (context, child) {
            // Hide indicators when focused or dragging
            final double effectiveOpacity = (_isFocused || _isDragging)
                ? 0.0
                : _indicatorFadeController.value;

            return ScrollHint(
              opacity: effectiveOpacity,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? Colors.transparent,
                ),
                child: Stack(
                  children: [
                    StringWheel(
                      values: widget.units,
                      initialValue: _current,
                      controller: _wheel,
                      enabled: widget.editable && !_isFocused,
                      height: 72,
                      itemExtent: 72,
                      width: 60,
                      borderColor: borderColor,
                      draggingBorderColor: Colors.transparent,
                      borderWidth: 1.5,
                      textStyle: AppFont.primaryTextStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: textColor,
                        decoration: TextDecoration.none,
                      ),
                      onChanged: (v) {
                        setState(() => _current = v);
                        widget.onUnitChanged(v);
                      },
                      onDraggingChanged: (dragging) {
                        setState(() {
                          _isDragging = dragging;
                        });
                      },
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
    );
  }
}

/// Stateless bottom sheet for unit selection with locale toggle
class _UnitSelectorSheet extends StatelessWidget {
  const _UnitSelectorSheet({
    super.key,
    required this.appTheme,
    required this.currentLocale,
    required this.options,
    required this.selectedUnit,
    required this.onLocaleChanged,
    required this.onCenteredValueChanged,
    required this.onUnitSelected,
  });

  final AppTheme appTheme;
  final String currentLocale;
  final List<SelectorOption> options;
  final String? selectedUnit;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<String> onCenteredValueChanged;
  final ValueChanged<String?> onUnitSelected;

  @override
  Widget build(BuildContext context) {
    final bool isUS = currentLocale.toUpperCase() == 'US';

    return Container(
        constraints: const BoxConstraints(minWidth: 400),
        decoration: BoxDecoration(
          color: appTheme.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: appTheme.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: appTheme.borderMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              // Unit system toggle with Arrow (matches archive sheet layout)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Unit system switch: Imperial / Metric (centered)
                      GestureDetector(
                        onTap: () {
                          final newLocale = isUS ? 'EU' : 'US';
                          onLocaleChanged(newLocale);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Imperial label - fixed width to prevent toggle shifting
                            SizedBox(
                              width: 80,
                              child: Text(
                                'Imperial',
                                textAlign: TextAlign.left,
                                style: AppFont.primaryTextStyle(
                                  context,
                                  fontSize: 16,
                                  fontWeight:
                                      isUS ? FontWeight.w600 : FontWeight.w400,
                                  color: isUS
                                      ? appTheme.secondary
                                      : appTheme.textMuted,
                                ),
                              ),
                            ),
                            // Switch container
                            UnitSystemSwitch(
                              isUS: isUS,
                              appTheme: appTheme,
                            ),
                            const SizedBox(width: 12),
                            // Metric label - fixed width to prevent toggle shifting
                            SizedBox(
                              width: 80,
                              child: Text(
                                'Metric',
                                textAlign: TextAlign.left,
                                style: AppFont.primaryTextStyle(
                                  context,
                                  fontSize: 16,
                                  fontWeight:
                                      !isUS ? FontWeight.w600 : FontWeight.w400,
                                  color: !isUS
                                      ? appTheme.secondary
                                      : appTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Arrow button (positioned right)
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: Icon(Icons.keyboard_arrow_down,
                              color: appTheme.text, size: 32),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Unit selector - rebuilds with fresh options on each locale change
              StringTape(
                values: options.map((opt) => opt.value).toList(),
                initialValue: selectedUnit,
                itemExtent: 48.0,
                enabled: true,
                textStyle: AppFont.primaryTextStyle(
                  context,
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: appTheme.borderMuted,
                  height: 1.2,
                ).copyWith(
                  letterSpacing: 1.5,
                ),
                selectedTextStyle: AppFont.primaryTextStyle(
                  context,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: appTheme.text,
                  height: 1.2,
                ).copyWith(
                  letterSpacing: 1.5,
                ),
                labelBuilder: (value) {
                  final option = options.firstWhere(
                    (opt) => opt.value == value,
                    orElse: () => SelectorOption(label: value, value: value),
                  );
                  return option.label;
                },
                onCenteredValueChanged: onCenteredValueChanged,
                onSelected: onUnitSelected,
              ),
            ],
          ),
        ));
  }
}
