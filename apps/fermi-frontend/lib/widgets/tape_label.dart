import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// A generic draggable tape label widget that displays a scrollable list of values
class TapeLabel extends StatefulWidget {
  const TapeLabel({
    super.key,
    required this.values,
    this.initialValue = '',
    this.editable = false,
    this.onChanged,
    this.onMenuTap,
  });

  final List<String> values;
  final String initialValue;
  final bool editable;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onMenuTap;

  @override
  State<TapeLabel> createState() => TapeLabelState();
}

class TapeLabelState extends State<TapeLabel>
    with SingleTickerProviderStateMixin {
  static const double _itemHeight = 60.0; // Height per item

  late AnimationController _controller;
  late Animation<double> _animation;
  late double _position; // Current scroll position (can be fractional)
  late String _currentLabel;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentLabel = widget.initialValue;

    // Find initial position based on initial value
    _position = widget.values.indexOf(_currentLabel).toDouble();
    if (_position < 0) _position = 0.0; // Default to first item if not found

    _controller = AnimationController(vsync: this);
    _controller.addListener(() {
      setState(() {
        _position = _animation.value;
        // Don't snap during animation - only update visual position
      });
    });
  }

  @override
  void didUpdateWidget(TapeLabel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update current label if values or initial value changed
    if (widget.initialValue != oldWidget.initialValue ||
        widget.values != oldWidget.values) {
      _currentLabel = widget.initialValue;
      _position = widget.values.indexOf(_currentLabel).toDouble();
      if (_position < 0) _position = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateCurrentLabel() {
    // Snap to nearest value
    final newIndex = _position.round().clamp(0, widget.values.length - 1);
    final newLabel = widget.values[newIndex];

    if (newLabel != _currentLabel) {
      _currentLabel = newLabel;
      widget.onChanged?.call(_currentLabel);
    }

    // Also update position to the snapped value
    _position = newIndex.toDouble();
  }

  void _onTap() {
    if (!widget.editable || _isDragging) return;
    widget.onMenuTap?.call();
  }

  /// Updates the current value and position from external source (e.g., menu selection)
  void updateValue(String newValue) {
    setState(() {
      _currentLabel = newValue;
      final targetIndex = widget.values.indexOf(newValue);
      if (targetIndex >= 0) {
        _position = targetIndex.toDouble();
      }
    });
    widget.onChanged?.call(_currentLabel);
  }

  void _animateToPosition(double targetPosition) {
    targetPosition =
        targetPosition.clamp(0.0, (widget.values.length - 1).toDouble());

    // Calculate animation duration based on distance (min 200ms, max 500ms)
    final distance = (targetPosition - _position).abs();
    final duration = Duration(
        milliseconds: (200 + (distance * 100)).clamp(200, 500).round());

    _controller.duration = duration;
    _animation = _controller.drive(
      Tween<double>(begin: _position, end: targetPosition),
    );

    // Add listener to hide neighbors when animation completes
    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isDragging = false;
          _updateCurrentLabel(); // Snap to final value and trigger callback
        });
        _controller.removeStatusListener(statusListener);
      }
    }

    _controller.addStatusListener(statusListener);

    _controller.reset();
    _controller.forward();
  }

  void _runPhysicsSimulation(double velocity) {
    // Convert velocity to units per second relative to our item height
    // Positive velocity should move tape downward (lower values);
    // negative velocity (fling up) moves toward higher magnitude (smaller indices)
    final unitsPerSecond = velocity / _itemHeight;

    // Create spring simulation with natural feel
    const spring = SpringDescription(
      mass: 1.0,
      stiffness: 500.0,
      damping: 20.0,
    );

    // Find the target position (snap to nearest item)
    final targetPosition = _position
        .round()
        .toDouble()
        .clamp(0.0, (widget.values.length - 1).toDouble());

    final simulation = SpringSimulation(
      spring,
      _position,
      targetPosition,
      unitsPerSecond,
    );

    _animation = _controller.drive(
      Tween<double>(begin: _position, end: targetPosition),
    );

    // Add listener to hide neighbors when animation completes
    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isDragging = false;
          _updateCurrentLabel(); // Snap to final value and trigger callback
        });
        _controller.removeStatusListener(statusListener);
      }
    }

    _controller.addStatusListener(statusListener);

    _controller.animateWith(simulation);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.editable) return;

    setState(() {
      _isDragging = true;
      // Convert pixel delta to position delta: swipe up (negative dy) => decrease position (higher magnitude)
      final deltaPosition = details.delta.dy / _itemHeight;
      _position = (_position + deltaPosition)
          .clamp(0.0, (widget.values.length - 1).toDouble());
      // Don't snap during drag - let it scroll continuously
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.editable) return;

    _isDragging = false;

    // Get velocity in pixels per second (swipe up negative -> decrease position/higher magnitude)
    final velocity = details.velocity.pixelsPerSecond.dy;

    if (velocity.abs() > 100) {
      // High velocity - run physics simulation
      _runPhysicsSimulation(velocity);
    } else {
      // Low velocity - just snap to nearest
      _animateToPosition(_position.round().toDouble());
    }
  }

  void _handlePanDown(DragDownDetails details) {
    if (!widget.editable) return;

    _controller.stop();
  }

  Widget _buildTapeItem(String value, double offset, AppTheme appTheme,
      {bool isCenter = false}) {
    final distance = offset.abs();

    // Calculate opacity and scale based on distance for smooth continuous scrolling
    final maxOpacity = isCenter ? 1.0 : (_isDragging ? 0.4 : 0.0);
    final opacity =
        (maxOpacity * (1.0 - (distance * 0.5))).clamp(0.0, maxOpacity);
    final scale = (1.0 - (distance * 0.15)).clamp(0.5, 1.0);
    const fontSize = 40.0;

    if (opacity <= 0.05) return const SizedBox.shrink(); // Hide if too faint

    // For empty values, show empty string but ensure the Text widget still renders
    final displayText = value.isEmpty ? ' ' : value;

    return Transform.translate(
      offset: Offset(0,
          -offset * 60), // Invert to match visual scroll with gesture direction
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Text(
            displayText,
            style: TextStyle(
              fontFamily: AppFont.of(context),
              fontSize: fontSize * scale,
              fontWeight: FontWeight.w300,
              color: _isDragging ? appTheme.danger : appTheme.text,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Calculate dynamic width based on font size and longest value
    const double fontSize = 40.0; // Same as used in _buildTapeItem
    const double charWidthFactor =
        0.7; // Approximate character width ratio for Barlow font

    // Find the longest value (including empty represented as space)
    final longestValue = widget.values.fold<String>('', (longest, current) {
      final displayValue = current.isEmpty ? ' ' : current;
      return displayValue.length > longest.length ? displayValue : longest;
    });

    final maxChars =
        math.max(1, longestValue.length); // Ensure at least 1 character width
    final dynamicWidth = fontSize * charWidthFactor * maxChars;

    Widget child = SizedBox(
      width: dynamicWidth,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tape effect container
            SizedBox(
              height: 80, // Enough height to show smooth tape scrolling
              child: ClipRect(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Build visible tape items around current position
                    for (int i = -3; i <= 3; i++)
                      if ((_position.floor() + i) >= 0 &&
                          (_position.floor() + i) < widget.values.length)
                        _buildTapeItem(
                          widget.values[(_position.floor() + i)
                              .clamp(0, widget.values.length - 1)],
                          i.toDouble() - (_position - _position.floor()),
                          appTheme,
                          isCenter:
                              i == (_position.round() - _position.floor()),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.editable) {
      child = GestureDetector(
        onTap: _onTap,
        onPanDown: _handlePanDown,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: child,
      );
    }

    return child;
  }
}
