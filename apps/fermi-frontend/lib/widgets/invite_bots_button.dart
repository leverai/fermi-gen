import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class InviteBotsButton extends StatefulWidget {
  final VoidCallback onPressed;
  final int botCount;
  final bool enabled;

  const InviteBotsButton({
    super.key,
    required this.onPressed,
    required this.botCount,
    this.enabled = true,
  });

  @override
  State<InviteBotsButton> createState() => _InviteBotsButtonState();
}

class _InviteBotsButtonState extends State<InviteBotsButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Use secondary color as requested
    final backgroundColor =
        widget.enabled ? appTheme.bgLight : appTheme.secondary;
    // Use a contrasting text color. Since secondary is vibrant/dark, white or bgLight usually works well.
    final foregroundColor = widget.enabled ? appTheme.text : appTheme.bgLight;

    final buttonLabel = widget.botCount == 1
        ? 'Invite 1 bot'
        : 'Invite ${widget.botCount} bots';

    return GestureDetector(
      onTapDown:
          widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp:
          widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(
          _isPressed ? appTheme.shadowOffset.dx : 0,
          _isPressed ? appTheme.shadowOffset.dy : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: appTheme.border,
            width: appTheme.borderWidth,
          ),
          boxShadow: [
            if (!_isPressed && widget.enabled)
              BoxShadow(
                color: appTheme.shadowColor,
                offset: appTheme.shadowOffset,
              ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy, // Robot icon for bots
              color: foregroundColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              buttonLabel,
              style: TextStyle(
                color: foregroundColor,
                fontFamily: AppFont.primaryOf(context),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
