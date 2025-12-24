import 'package:flutter/material.dart';

/// A widget that constrains its child's width to a maximum value (default 540px)
/// and centers it, useful for responsive design on wide screens.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color? backgroundColor;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 540.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
