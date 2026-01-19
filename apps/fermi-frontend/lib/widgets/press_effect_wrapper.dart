// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fermi_frontend/services/feedback_service.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// A wrapper that adds a splash effect and a 3D push-down animation on press.
///
/// When pressed, the child widget is translated by the shadow offset,
/// and the shadow offset is reduced to zero, creating a "push-down" effect.
class PressEffectWrapper extends StatefulWidget {
  const PressEffectWrapper({
    super.key,
    required this.child,
    required this.onTap,
    required this.decoration,
    this.enablePushDown = true,
    this.borderRadius,
    this.padding,
    this.splashColor,
  });

  /// The widget to be displayed inside the wrapper.
  final Widget child;

  /// Callback when the wrapper is tapped.
  final VoidCallback? onTap;

  /// The decoration for the card, including background color and shadow.
  final BoxDecoration decoration;

  /// Whether to enable the 3D push-down animation.
  final bool enablePushDown;

  /// Optional border radius for the splash effect.
  /// If null, it tries to extract it from [decoration].
  final BorderRadius? borderRadius;

  /// Optional padding inside the card.
  final EdgeInsetsGeometry? padding;

  /// Optional custom splash color.
  final Color? splashColor;

  @override
  State<PressEffectWrapper> createState() => _PressEffectWrapperState();
}

class _PressEffectWrapperState extends State<PressEffectWrapper> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final boxStyle = widget.decoration;
    final shadow = (boxStyle.boxShadow?.isNotEmpty ?? false)
        ? boxStyle.boxShadow!.first
        : null;

    final offset = shadow?.offset ?? Offset.zero;
    final effectiveOffset =
        (_isPressed && widget.enablePushDown) ? Offset.zero : offset;

    final translation =
        (_isPressed && widget.enablePushDown) ? offset : Offset.zero;

    final borderRadius = widget.borderRadius ??
        (boxStyle.borderRadius as BorderRadius?) ??
        BorderRadius.circular(appTheme.borderRadius);

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Listener(
        onPointerDown: widget.onTap != null
            ? (_) => setState(() => _isPressed = true)
            : null,
        onPointerUp: widget.onTap != null
            ? (_) => setState(() => _isPressed = false)
            : null,
        onPointerCancel: widget.onTap != null
            ? (_) => setState(() => _isPressed = false)
            : null,
        child: GestureDetector(
          onTap: widget.onTap != null
              ? () {
                  FeedbackService.instance.lightTap();
                  widget.onTap!();
                }
              : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
            transform:
                Matrix4.translationValues(translation.dx, translation.dy, 0),
            decoration: boxStyle.copyWith(
              boxShadow: shadow != null
                  ? [
                      shadow.copyWith(
                        offset: effectiveOffset,
                      ),
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: borderRadius,
                splashColor:
                    widget.splashColor ?? Colors.black.withOpacity(0.1),
                child: Padding(
                  padding: widget.padding ?? EdgeInsets.zero,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
