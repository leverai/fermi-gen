import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

class StringTapeController {
  void Function(String value)? _jumpTo;
  void Function(String value, Duration duration)? _animateTo;

  void _bind({
    required void Function(String value) jumpTo,
    required void Function(String value, Duration duration) animateTo,
  }) {
    _jumpTo = jumpTo;
    _animateTo = animateTo;
  }

  void jumpTo(String value) {
    final fn = _jumpTo;
    if (fn != null) fn(value);
  }

  Future<void> animateTo(String value, Duration duration) async {
    final fn = _animateTo;
    if (fn != null) fn(value, duration);
  }
}

/// A tape widget that shows 1-2 values around the centered value.
/// Selection is done by tapping the centered item.
class StringTape extends StatefulWidget {
  const StringTape({
    super.key,
    required this.values,
    this.initialValue,
    this.onSelected,
    this.itemExtent = 56.0,
    this.enabled = true,
    this.textStyle,
    this.selectedTextStyle,
    this.controller,
    this.labelBuilder,
  });

  final List<String> values;
  final String? initialValue;
  final ValueChanged<String>? onSelected; // Called when user taps centered item
  final double itemExtent;
  final bool enabled;
  final TextStyle? textStyle;
  final TextStyle? selectedTextStyle; // Style for centered/selected item
  final StringTapeController? controller;
  final String Function(String value)? labelBuilder; // Optional label formatter

  @override
  State<StringTape> createState() => _StringTapeState();
}

class _StringTapeState extends State<StringTape> {
  late FixedExtentScrollController _controller;
  int _selectedIndex = 0;
  bool _isPressing = false;

  static const Duration _pressFeedbackDelay = Duration(milliseconds: 100);
  static const double _pressPadding = 24.0;

  @override
  void initState() {
    super.initState();
    final int start = _indexOf(widget.initialValue);
    _selectedIndex = start;
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
    if (value == null || widget.values.isEmpty) return 0;
    final int idx = widget.values.indexOf(value);
    return idx >= 0 ? idx : 0;
  }

  void _jumpTo(String value) {
    if (widget.values.isEmpty) return;
    final int idx = _indexOf(value).clamp(0, widget.values.length - 1);
    _controller.jumpToItem(idx);
    setState(() => _selectedIndex = idx);
  }

  Future<void> _animateTo(String value, Duration duration) async {
    if (widget.values.isEmpty) return;
    final int idx = _indexOf(value).clamp(0, widget.values.length - 1);
    await _controller.animateToItem(
      idx,
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
    setState(() => _selectedIndex = idx);
  }

  void _onItemTapped(int index) {
    if (!widget.enabled || index < 0 || index >= widget.values.length) return;
    // If tapping the centered item, select it
    if (index == _selectedIndex) {
      // Show press feedback
      setState(() => _isPressing = true);
      Future.delayed(_pressFeedbackDelay, () {
        if (mounted) {
          setState(() => _isPressing = false);
          widget.onSelected?.call(widget.values[index]);
        }
      });
    } else {
      // If tapping a non-centered item, animate to center it (without selecting)
      _animateTo(widget.values[index], const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final TextStyle defaultTextStyle = widget.textStyle ??
        AppFont.primaryTextStyle(
          context,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: appTheme.textMuted,
          height: 1.2,
        );

    final TextStyle defaultSelectedStyle = widget.selectedTextStyle ??
        AppFont.primaryTextStyle(
          context,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: appTheme.text,
          height: 1.2,
        );

    if (widget.values.isEmpty) {
      return SizedBox(height: widget.itemExtent * 4);
    }

    // Show top border when there are >=2.5 items above center (selected index >= 3)
    final bool showTopBorder = _selectedIndex >= 3;

    // Calculate center position for press feedback overlay
    final double centerY = widget.itemExtent * 2; // Center of the 4-item view

    // Get the selected value's label for sizing the highlight
    final String selectedValue = _selectedIndex < widget.values.length
        ? widget.values[_selectedIndex]
        : '';
    final String selectedLabel = widget.labelBuilder != null
        ? widget.labelBuilder!(selectedValue)
        : selectedValue;

    return Stack(
      children: [
        GestureDetector(
          onTapUp: (details) {
            if (!widget.enabled) return;
            // Calculate which item was tapped based on Y position
            final double tapY = details.localPosition.dy;
            final double centerY =
                widget.itemExtent * 2; // Center of the 4-item view
            final double offsetFromCenter = tapY - centerY;
            final int itemOffset =
                (offsetFromCenter / widget.itemExtent).round();
            final int tappedIndex = (_selectedIndex + itemOffset)
                .clamp(0, widget.values.length - 1);
            _onItemTapped(tappedIndex);
          },
          child: SizedBox(
            height: widget.itemExtent *
                4, // Show 4 items total (1-2 above, center, 1-2 below)
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: widget.itemExtent,
              physics: widget.enabled
                  ? const FixedExtentScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              perspective: 0.003,
              diameterRatio:
                  1.5, // Show more items around center (smaller = more visible items)
              onSelectedItemChanged: (index) {
                setState(() => _selectedIndex = index);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  if (index < 0 || index >= widget.values.length) return null;

                  final String value = widget.values[index];
                  final String label =
                      widget.labelBuilder?.call(value) ?? value;
                  final bool isSelected = index == _selectedIndex;

                  return Container(
                    height: widget.itemExtent,
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style:
                          isSelected ? defaultSelectedStyle : defaultTextStyle,
                      textAlign: TextAlign.center,
                    ),
                  );
                },
                childCount: widget.values.length,
              ),
            ),
          ),
        ),
        // Press feedback overlay - shows when centered item is pressed
        if (_isPressing)
          Positioned(
            top: centerY - (widget.itemExtent * 0.5),
            left: 0,
            right: 0,
            height: widget.itemExtent,
            child: Center(
              child: AnimatedOpacity(
                opacity: _isPressing ? 0.3 : 0.0,
                duration: _pressFeedbackDelay,
                child: IntrinsicWidth(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: _pressPadding),
                    height: widget.itemExtent,
                    decoration: BoxDecoration(
                      color: appTheme.info,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Opacity(
                      opacity: 0, // Hide the text, we only need it for sizing
                      child: Text(
                        selectedLabel,
                        style: defaultSelectedStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Top border overlay - doesn't affect scroll position
        if (showTopBorder)
          Container(
            height: 1.0,
            color: appTheme.borderMuted.withOpacity(.2),
          ),
      ],
    );
  }
}
