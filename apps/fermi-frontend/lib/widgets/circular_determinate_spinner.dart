import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// A small circular spinner that can be determinate or indeterminate.
///
/// - When [progress] is provided, shows a determinate progress indicator.
/// - When [progress] is null, shows an indeterminate spinner.
/// - Designed to be overlaid without affecting layout.
/// - Size defaults to 16px; stroke is thin to stay subtle.
class CircularDeterminateSpinner extends StatelessWidget {
  const CircularDeterminateSpinner({
    super.key,
    this.progress, // 0.0 .. 1.0, or null for indeterminate
    this.size = 16.0,
    this.backgroundOpacity = 0.18,
    this.color,
  });

  final double? progress;
  final double size;
  final double backgroundOpacity;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).extension<AppTheme>();
    final Color defaultFg = appTheme!.primary;
    final Color fg = color ?? defaultFg;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: progress?.clamp(0.0, 1.0),
        strokeWidth: 5,
        valueColor: AlwaysStoppedAnimation<Color>(fg),
        // ignore: deprecated_member_use
        backgroundColor: fg.withOpacity(backgroundOpacity),
      ),
    );
  }
}
