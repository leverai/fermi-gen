import 'package:flutter/material.dart';
import 'package:fermi_frontend/widgets/color_config_dialog.dart';
import 'package:fermi_frontend/state/theme_config_service.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// Floating action button that opens the color configuration dialog.
class ThemeConfigFloatingButton extends StatelessWidget {
  const ThemeConfigFloatingButton({
    super.key,
    required this.themeConfigService,
  });

  final ThemeConfigService themeConfigService;

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return FloatingActionButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => ColorConfigDialog(
            themeConfigService: themeConfigService,
          ),
        );
      },
      backgroundColor: appTheme.primary,
      foregroundColor: appTheme.bg,
      child: const Icon(Icons.palette),
    );
  }
}
