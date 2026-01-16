import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// A widget that overlays up/down arrows on a child widget to indicate scrollability.
///
/// The arrows fade out based on the provided [opacity].
class ScrollHint extends StatelessWidget {
  const ScrollHint({
    super.key,
    required this.child,
    required this.opacity,
    this.iconSize = 16.0,
    this.verticalPadding = 2.0,
  });

  final Widget child;
  final double opacity;
  final double iconSize;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Use a low opacity for the arrows so they are subtle
    // ignore: deprecated_member_use
    final Color arrowColor = appTheme.borderMuted.withOpacity(0.5 * opacity);

    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        // Up arrow
        Positioned(
          top: verticalPadding,
          child: IgnorePointer(
            child: Icon(
              Icons.keyboard_arrow_up,
              size: iconSize,
              color: arrowColor,
            ),
          ),
        ),
        // Down arrow
        Positioned(
          bottom: verticalPadding,
          child: IgnorePointer(
            child: Icon(
              Icons.keyboard_arrow_down,
              size: iconSize,
              color: arrowColor,
            ),
          ),
        ),
      ],
    );
  }
}
