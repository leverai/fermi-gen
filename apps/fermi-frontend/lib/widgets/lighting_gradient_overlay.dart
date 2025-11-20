import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// Subtle lighting gradient overlay that creates a glow effect from bottom to top.
/// Uses the theme's foreground color for consistency across different categories.
class LightingGradientOverlay extends StatelessWidget {
  const LightingGradientOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final Color gradientColor = appTheme.danger;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            // ignore: deprecated_member_use
            gradientColor.withOpacity(0.03),
            Colors.transparent,
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
    );
  }
}
