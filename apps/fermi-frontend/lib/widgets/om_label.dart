import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/utils/om_constants.dart';
import 'package:fermi_frontend/widgets/bottom_sheet_height_provider.dart';
import 'string_wheel.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/tap_indicator.dart';
import 'package:fermi_frontend/widgets/string_tape.dart';
import 'package:fermi_frontend/utils/logger.dart';

class OmLabelController {
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

  /// Close the OM selector if it's open
  void close() {
    final fn = _close;
    if (fn != null) fn();
  }
}

class OmLabel extends StatefulWidget {
  const OmLabel({
    super.key,
    this.initialValue = '',
    this.editable = false,
    this.revealColor,
    this.onChanged,
    this.controller,
    this.onSelectorComplete,
    this.onBeforeOpen,
  });

  final String initialValue;
  final bool editable;
  final Color? revealColor; // Color to use during reveal (score-based)
  final ValueChanged<String>? onChanged;
  final OmLabelController? controller;
  final VoidCallback?
      onSelectorComplete; // Called when selector popup closes with selection
  final VoidCallback?
      onBeforeOpen; // Called before selector opens (to close other inputs)

  @override
  State<OmLabel> createState() => _OmLabelState();
}

class _OmLabelState extends State<OmLabel> with SingleTickerProviderStateMixin {
  // Use shared constants for order of magnitude symbols
  static const List<String> _magnitudeValues = orderOfMagnitudeSymbols;

  final StringWheelController _wheel = StringWheelController();
  String? _current;
  late final AnimationController _indicatorFadeController;
  bool _isFocused = false;
  bool _bottomSheetOpen = false;
  bool _isTransitioningToNext =
      false; // Track if transitioning to next selector
  bool _isDragging = false; // Track StringWheel dragging state

  // Helper to capitalize first letter
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

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

    widget.controller?._bind(
      jumpTo: (v) {
        setState(() => _current = v);
        _wheel.jumpTo(v);
        // Notify parent to sync state when jumping programmatically
        widget.onChanged?.call(v);
      },
      animateTo: (v, d) async {
        AppLogger.debug(
            'OmLabel.animateTo: value=$v, duration=${d.inMilliseconds}ms, current=$_current');
        await _wheel.animateTo(v, d);
        AppLogger.debug('OmLabel.animateTo: _wheel.animateTo returned');
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
      close: _closeOmSelector,
    );
  }

  void _requestFocus() {
    if (!widget.editable) return;
    _showOmSelector();
  }

  void _showOmSelector() {
    if (!widget.editable) return;
    if (_bottomSheetOpen) return; // Prevent multiple bottom sheets

    // Notify parent before opening so it can close other inputs (e.g., numpad)
    widget.onBeforeOpen?.call();

    setState(() {
      _isFocused = true;
      _bottomSheetOpen = true;
    });

    final GlobalKey sheetKey = GlobalKey();
    final heightNotifier = BottomSheetHeightProvider.maybeOf(context);

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
            // Measure height after build and notify provider
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final RenderBox? box =
                  sheetKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && heightNotifier != null) {
                heightNotifier.value = box.size.height;
              }
            });

            // Build options list for tape
            final List<String> tapeValues = [
              '', // Empty option first
              ...orderOfMagnitudeSymbols.sublist(1),
            ];

            return Container(
              key: sheetKey,
              constraints: const BoxConstraints(minWidth: 400),
              decoration: BoxDecoration(
                color: appTheme.bg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: appTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Instruction text
                    Text(
                      'Order of Magnitude',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: appTheme.border,
                        height: 1.2,
                      ).copyWith(
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 24),
                    // StringTape for selection
                    StringTape(
                      values: tapeValues,
                      initialValue: _current,
                      itemExtent: 48.0,
                      enabled: true,
                      textStyle: AppFont.primaryTextStyle(
                        context,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: appTheme.highlight,
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
                        if (value.isEmpty) return 'None';
                        final int index =
                            orderOfMagnitudeSymbols.indexOf(value);
                        if (index > 0 &&
                            index <= orderOfMagnitudeWords.length) {
                          return _capitalize(orderOfMagnitudeWords[index]);
                        }
                        return value;
                      },
                      onSelected: (value) {
                        // Update modal state first to show visual feedback
                        if (mounted) {
                          setModalState(() {
                            _current = value;
                          });
                          _wheel.jumpTo(value);
                          widget.onChanged?.call(value);
                          // Delay closing to allow visual feedback
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (mounted && context.mounted) {
                              // Mark that we're transitioning to the next selector
                              final hasNext = widget.onSelectorComplete != null;
                              if (hasNext) {
                                _isTransitioningToNext = true;
                              }
                              Navigator.of(context).pop();
                              // Notify completion to trigger next step (e.g., open unit selector)
                              widget.onSelectorComplete?.call();
                            }
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
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

      // Capture height at close time to detect if next selector updates it
      final double? heightAtClose = heightNotifier?.value;

      // Handle height reset
      // Simple rule: if transitioning to next selector, DON'T reset height immediately
      // The next selector will take ownership and set/reset height as needed
      // However, if the next selector doesn't open (e.g., no units), we need a fallback
      if (!_isTransitioningToNext) {
        // Not transitioning - reset height after modal dismiss animation
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && heightNotifier != null) {
            heightNotifier.value = 0.0;
          }
        });
      } else {
        // Transitioning - wait to see if next selector opens
        // If height hasn't changed (still matches height at close), next selector didn't open
        // This is a fallback for cases where units are empty or selector fails to open
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && heightNotifier != null && heightAtClose != null) {
            final currentHeight = heightNotifier.value;
            // If height is still the same as when we closed (or very close), next selector didn't open
            // Use a small threshold to account for measurement differences
            if (currentHeight > 0 &&
                (currentHeight - heightAtClose).abs() < 5.0) {
              // Height hasn't changed - next selector didn't open, reset it
              heightNotifier.value = 0.0;
            }
            // If height changed, next selector opened and is managing height, do nothing
          }
        });
      }

      // Reset the flag for next time
      _isTransitioningToNext = false;
    });

    // No focus management needed - this uses a modal bottom sheet, not keyboard input.
  }

  void _closeOmSelector() {
    if (_bottomSheetOpen && mounted) {
      Navigator.of(context).pop();
      // State will be reset by the .then() callback in _showOmSelector
    }
  }

  @override
  void dispose() {
    _indicatorFadeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OmLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      widget.controller?._bind(
        jumpTo: (v) {
          setState(() => _current = v);
          _wheel.jumpTo(v);
          // Notify parent to sync state when jumping programmatically
          widget.onChanged?.call(v);
        },
        animateTo: (v, d) async {
          AppLogger.debug(
              'OmLabel.animateTo (didUpdateWidget): value=$v, duration=${d.inMilliseconds}ms, current=$_current');
          await _wheel.animateTo(v, d);
          AppLogger.debug(
              'OmLabel.animateTo (didUpdateWidget): _wheel.animateTo returned');
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
        close: _closeOmSelector,
      );
    }
    // Close the bottom sheet if widget becomes non-editable (e.g., deadline reached)
    if (oldWidget.editable && !widget.editable) {
      _closeOmSelector();
    }
  }

  @override
  Widget build(BuildContext context) {
    _current ??= widget.initialValue;
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Determine colors based on focus and reveal state
    final Color textColor =
        _isFocused ? appTheme.primary : (widget.revealColor ?? appTheme.text);
    final Color borderColor =
        _isFocused ? appTheme.primary : Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: GestureDetector(
        onTap: widget.editable ? _showOmSelector : null,
        child: Stack(
          children: [
            StringWheel(
              values: _magnitudeValues,
              initialValue: _current,
              controller: _wheel,
              enabled: widget.editable && !_isFocused,
              height: 72,
              itemExtent: 72,
              width: 60,
              borderColor: borderColor,
              draggingBorderColor: appTheme.primary,
              borderWidth: 1.5,
              borderRadius: 8.0,
              textStyle: AppFont.secondaryTextStyle(
                context,
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: textColor,
                decoration: TextDecoration.none,
              ),
              onChanged: (v) {
                _current = v;
                widget.onChanged?.call(v);
              },
              onDraggingChanged: (dragging) {
                setState(() {
                  _isDragging = dragging;
                });
              },
            ),
            // Tap indicator line at bottom
            // Hide when focused or dragging (scroll indicator is showing)
            AnimatedBuilder(
              animation: _indicatorFadeController,
              builder: (context, child) {
                // Hide tap indicator when scroll indicator is showing (focused or dragging)
                final double effectiveOpacity = (_isFocused || _isDragging)
                    ? 0.0
                    : _indicatorFadeController.value;
                return TapIndicator(
                  opacity: effectiveOpacity,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
