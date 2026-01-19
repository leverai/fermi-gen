import 'package:flutter/material.dart';
import 'package:fermi_frontend/services/feedback_service.dart';

/// A wrapper that adds a simple bounce (scale) effect on press.
///
/// When pressed, the child widget is scaled down, and then it
/// bounces back to its original size when released.
class BounceEffectWrapper extends StatefulWidget {
  const BounceEffectWrapper({
    super.key,
    required this.child,
    required this.onTap,
    this.decoration,
    this.padding,
    this.borderRadius,
    this.bounceScale = 0.95,
  });

  /// The widget to be displayed inside the wrapper.
  final Widget child;

  /// Callback when the wrapper is tapped.
  final VoidCallback? onTap;

  /// The decoration for the card.
  final BoxDecoration? decoration;

  /// Optional padding inside the card.
  final EdgeInsetsGeometry? padding;

  /// Optional border radius for the splash effect and decoration.
  final BorderRadius? borderRadius;

  /// The scale to apply when pressed. Defaults to 0.95.
  final double bounceScale;

  @override
  State<BounceEffectWrapper> createState() => _BounceEffectWrapperState();
}

class _BounceEffectWrapperState extends State<BounceEffectWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.bounceScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.borderRadius ??
        widget.decoration?.borderRadius as BorderRadius? ??
        BorderRadius.zero;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap != null
          ? () {
              FeedbackService.instance.lightTap();
              widget.onTap!();
            }
          : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: widget.decoration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: effectiveBorderRadius,
              splashColor: Colors.black.withOpacity(0.05),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: widget.padding ?? EdgeInsets.zero,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
