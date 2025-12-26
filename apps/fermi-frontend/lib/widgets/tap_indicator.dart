import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// A subtle horizontal line indicator at the bottom of a tappable element.
///
/// Used to provide visual feedback that an element is interactive. The indicator
/// fades out during reveal animations to indicate the element is no longer interactive.
///
/// Typically used within a [Stack] with an [AnimatedBuilder] to animate opacity:
/// ```dart
/// AnimatedBuilder(
///   animation: controller,
///   builder: (context, child) {
///     return TapIndicator(opacity: controller.value);
///   },
/// )
/// ```
class TapIndicator extends StatelessWidget {
  const TapIndicator({
    super.key,
    required this.opacity,
    this.horizontalPadding = 12.0,
    this.height = 1,
  });

  /// Opacity value for the indicator (0.0 = transparent, 1.0 = fully visible).
  /// Typically animated from 1.0 to 0.0 during reveal events.
  final double opacity;

  /// Horizontal padding on left and right sides to make the indicator shorter
  /// than the full width of the element. Defaults to 12.0 pixels.
  final double horizontalPadding;

  /// Height of the indicator line in pixels. Defaults to 1 pixel.
  final double height;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Positioned(
      bottom: 0,
      left: horizontalPadding,
      right: horizontalPadding,
      child: Container(
        height: height,
        color: appTheme.borderMuted.withAlpha((opacity * 255).toInt()),
      ),
    );
  }
}
