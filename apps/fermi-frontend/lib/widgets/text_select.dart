import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class TextSelect extends StatelessWidget {
  const TextSelect({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final textColor =
        isSelected ? appTheme.danger : appTheme.textMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: isSelected
            ? (Transform.translate(offset: const Offset(0, -4)).transform)
            : Matrix4.identity(),
        child: Padding(
          padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppFont.of(context),
              fontWeight: FontWeight.w300,
              fontSize: 16,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
