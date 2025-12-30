import 'package:flutter/material.dart';

/// A widget that constrains its child's width to a maximum value (default 540px)
/// and centers it, useful for responsive design on wide screens.
///
/// Optionally handles safe area insets for consistent safe area handling
/// across all screens. By default, safe area is applied on all sides.
///
/// SafeArea automatically handles:
/// - Device notches (iPhone X+, Android punch-hole cameras)
/// - Status bars and navigation bars
/// - Home indicators
/// - All system UI overlays across different device types
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color? backgroundColor;
  final bool useSafeArea;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 540.0,
    this.backgroundColor,
    this.useSafeArea = true,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    if (useSafeArea) {
      content = SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        child: content,
      );
    }

    return content;
  }
}
