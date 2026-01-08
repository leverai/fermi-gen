import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class ShareButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool iconOnly;
  const ShareButton(
      {super.key, required this.onPressed, this.iconOnly = false});

  @override
  State<ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<ShareButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Use secondary color as requested
    final backgroundColor = appTheme.secondary;
    // Use a contrasting text color. Since secondary is vibrant/dark, white or bgLight usually works well.
    final foregroundColor = appTheme.bg;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(
          _isPressed ? appTheme.shadowOffset.dx : 0,
          _isPressed ? appTheme.shadowOffset.dy : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: widget.iconOnly ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.iconOnly ? null : BorderRadius.circular(12),
          boxShadow: [
            if (!_isPressed)
              BoxShadow(
                color: appTheme.secondaryMuted,
                offset: appTheme.shadowOffset,
              ),
          ],
        ),
        padding: widget.iconOnly
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        width: widget.iconOnly ? 52 : null,
        height: widget.iconOnly ? 52 : null,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_add_alt_1_rounded, // Use a "Invite" style icon
                color: foregroundColor,
                size: 24,
              ),
              if (!widget.iconOnly) ...[
                const SizedBox(width: 8),
                Text(
                  'Invite friends',
                  style: TextStyle(
                    color: foregroundColor,
                    fontFamily: AppFont.primaryOf(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
