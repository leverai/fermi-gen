import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/utils/logger.dart';

class StringWheelController {
  void Function(String value)? _jumpTo;
  Future<void> Function(String value, Duration duration)? _animateTo;
  void Function(bool enabled)? _setReveal; // reserved for parity with digits

  void _bind({
    required void Function(String value) jumpTo,
    required Future<void> Function(String value, Duration duration) animateTo,
    void Function(bool enabled)? setReveal,
  }) {
    _jumpTo = jumpTo;
    _animateTo = animateTo;
    _setReveal = setReveal;
  }

  void jumpTo(String value) {
    final fn = _jumpTo;
    if (fn != null) fn(value);
  }

  Future<void> animateTo(String value, Duration duration) async {
    final fn = _animateTo;
    if (fn != null) await fn(value, duration);
  }

  void setRevealEnabled(bool enabled) {
    final fn = _setReveal;
    if (fn != null) fn(enabled);
  }
}

/// A single-column string selector using ListWheelScrollView with
/// fixed-extent physics identical to DigitWheels.
class StringWheel extends StatefulWidget {
  const StringWheel({
    super.key,
    required this.values,
    this.initialValue,
    this.onChanged,
    this.height = 50,
    this.itemExtent = 72,
    this.width,
    this.enabled = true,
    this.textStyle,
    this.controller,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = 8.0,
    this.draggingBorderColor,
    this.onDraggingChanged,
  });

  final List<String> values;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final double height;
  final double itemExtent;
  final double? width;
  final bool enabled;
  final TextStyle? textStyle;
  final StringWheelController? controller;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final Color? draggingBorderColor;
  final ValueChanged<bool>?
      onDraggingChanged; // Callback when dragging state changes

  @override
  State<StringWheel> createState() => _StringWheelState();
}

class _StringWheelState extends State<StringWheel> {
  late FixedExtentScrollController _controller;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    final int start = _indexOf(widget.initialValue);
    _controller = FixedExtentScrollController(initialItem: start);
    widget.controller?._bind(
      jumpTo: _jumpTo,
      animateTo: _animateTo,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexOf(String? value) {
    if (value == null) return 0;
    final int idx = widget.values.indexOf(value);
    return idx >= 0 ? idx : 0;
  }

  void _emitChanged() {
    if (widget.values.isEmpty) return;
    final int idx = _controller.selectedItem.clamp(0, widget.values.length - 1);
    widget.onChanged?.call(widget.values[idx]);
  }

  void _jumpTo(String value) {
    if (widget.values.isEmpty) return;
    final int idx = _indexOf(value).clamp(0, widget.values.length - 1);
    _controller.jumpToItem(idx);
    // Don't call _emitChanged() - jumpTo is for programmatic changes
    // User scroll interactions trigger onSelectedItemChanged which calls _emitChanged
  }

  Future<void> _animateTo(String value, Duration duration) async {
    if (widget.values.isEmpty) {
      AppLogger.debug('StringWheel._animateTo: ABORT - values.isEmpty');
      return;
    }
    final int idx = _indexOf(value).clamp(0, widget.values.length - 1);
    final int currentIdx = _controller.selectedItem;
    AppLogger.debug('StringWheel._animateTo: value=$value, idx=$idx, currentIdx=$currentIdx, duration=${duration.inMilliseconds}ms');
    AppLogger.debug('StringWheel._animateTo: Calling animateToItem($idx, duration=$duration)');
    await _controller.animateToItem(
      idx,
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
    AppLogger.debug('StringWheel._animateTo: animateToItem returned');
    // onSelectedItemChanged/ScrollEnd will emit change
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = widget.textStyle ??
        AppFont.secondaryTextStyle(
          context,
          fontSize: 28,
          fontWeight: FontWeight.w300,
          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
          decoration: TextDecoration.none,
        );

    return SizedBox(
      height: widget.height,
      width: widget.width ?? widget.itemExtent,
      child: Center(
        child: SizedBox(
          height: widget.itemExtent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _dragging
                    ? (widget.draggingBorderColor ??
                        widget.borderColor ??
                        (Theme.of(context).textTheme.bodyLarge?.color ??
                            Colors.black))
                    : (widget.borderColor ?? Colors.transparent),
                width: widget.borderWidth,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: ClipRect(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollStartNotification) {
                      setState(() => _dragging = true);
                      widget.onDraggingChanged?.call(true);
                    } else if (n is ScrollEndNotification) {
                      setState(() => _dragging = false);
                      widget.onDraggingChanged?.call(false);
                      _emitChanged();
                    }
                    return false;
                  },
                  child: ListWheelScrollView.useDelegate(
                    controller: _controller,
                    itemExtent: widget.itemExtent,
                    physics: widget.enabled
                        ? const FixedExtentScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    perspective: 0.003,
                    diameterRatio: 1.6,
                    onSelectedItemChanged: (_) => _emitChanged(),
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, index) {
                        if (index < 0 || index >= widget.values.length) {
                          return null;
                        }
                        return Center(
                          child: Text(
                            widget.values[index],
                            style: style,
                          ),
                        );
                      },
                      childCount: widget.values.length,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
