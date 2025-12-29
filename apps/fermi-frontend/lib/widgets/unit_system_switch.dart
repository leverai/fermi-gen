import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// Custom switch widget for unit system selection.
///
/// A rectangular container with a square child that animates between positions.
/// Used to toggle between Imperial (US) and Metric (EU) unit systems.
///
/// The switch consists of:
/// - A rectangular outer container (48x24) with a 2px border
/// - A square inner child (24x24) with a 1px border that slides between positions
/// - Smooth animation when toggling between states
class UnitSystemSwitch extends StatefulWidget {
  const UnitSystemSwitch({
    super.key,
    required this.isUS,
    required this.appTheme,
  });

  /// Whether the switch is in the US (Imperial) position.
  /// When `true`, the square is on the left; when `false`, it's on the right (Metric).
  final bool isUS;

  /// The app theme to use for colors (border, secondary).
  final AppTheme appTheme;

  @override
  State<UnitSystemSwitch> createState() => _UnitSystemSwitchState();
}

class _UnitSystemSwitchState extends State<UnitSystemSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    // Set initial position
    _controller.value = widget.isUS ? 0.0 : 1.0;
  }

  @override
  void didUpdateWidget(UnitSystemSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isUS != widget.isUS) {
      _controller.animateTo(widget.isUS ? 0.0 : 1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate dimensions: rectangle should be wide enough for square + spacing
    // Square size: 24x24 (typical for switches)
    // Rectangle: 2 * square size = 48 width, square height = 24
    const double circleRadius = 20.0;
    const double rectangleWidth = circleRadius * 2;
    const double rectangleHeight = circleRadius;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Calculate square position: left (0.0) to right (1.0)
        final double squarePosition = _animation.value;
        final double leftOffset =
            squarePosition * (rectangleWidth - circleRadius);

        return Container(
          width: rectangleWidth,
          height: rectangleHeight,
          decoration: BoxDecoration(
            color: widget.appTheme.bgDark,
            borderRadius: BorderRadius.circular(12), // Square edges
          ),
          child: Stack(
            children: [
              Positioned(
                left: leftOffset,
                top: 0,
                child: Container(
                  width: circleRadius,
                  height: circleRadius,
                  decoration: BoxDecoration(
                    color: widget.appTheme.secondary,
                    borderRadius: BorderRadius.circular(100), // Square edges
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
