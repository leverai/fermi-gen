import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  bool _hasInvitedBots = false;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Button is disabled if it was already used or if explicitly disabled
    final isEnabled = widget.enabled && !_hasInvitedBots;

    // Use secondary color as requested
    final backgroundColor =
        isEnabled ? appTheme.bgLight : appTheme.borderMuted.withOpacity(0.2);
    // Use a contrasting text color. Since secondary is vibrant/dark, white or bgLight usually works well.
    final foregroundColor = isEnabled ? appTheme.text : appTheme.bgLight;

    final buttonLabel = 'Invite bots';

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() {
                _isPressed = false;
                _hasInvitedBots = true;
              });
              widget.onPressed();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: null, // Handled in onTapUp
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
            if (!_isPressed && isEnabled)
              BoxShadow(
                color: appTheme.shadowColor,
                offset: appTheme.shadowOffset,
              ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/add_bot.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                foregroundColor,
                BlendMode.srcIn,
              ),
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
