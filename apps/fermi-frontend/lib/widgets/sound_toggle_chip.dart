import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

class SoundToggleChip extends StatelessWidget {
  const SoundToggleChip({
    super.key,
    required this.isOn,
  });

  final bool isOn;

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        isOn ? 'On' : 'Off',
        style: AppFont.primaryTextStyle(
          context,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: isOn ? appTheme.primary : appTheme.secondary,
        ),
      ),
    );
  }
}
