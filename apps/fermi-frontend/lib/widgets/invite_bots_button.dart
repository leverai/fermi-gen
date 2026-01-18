import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:flutter_svg/flutter_svg.dart';

class InviteBotsButton extends StatefulWidget {
  final VoidCallback onPressed;
  final int botCount;
  final bool enabled;
  final bool iconOnly;

  const InviteBotsButton({
    super.key,
    required this.onPressed,
    required this.botCount,
    this.enabled = true,
    this.iconOnly = false,
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

    // Design tokens
    // Using 'bg' (surface) for face to contrast with 'bgDark' background of Lobby
    // Using 'border' for the outline
    // Using 'borderMuted' for the hard shadow
    final Color faceColor = appTheme.bg;
    final Color borderColor =
        isEnabled ? appTheme.border : appTheme.borderMuted.withOpacity(0.5);
    final Color shadowColor = appTheme.borderMuted;
    final Color iconColor = isEnabled ? appTheme.text : appTheme.textMuted;

    // Shadow offset calculation (mimics MainButton's hard shadow)
    final double xOffset = _isPressed ? appTheme.shadowOffset.dx : 0;
    final double yOffset = _isPressed ? appTheme.shadowOffset.dy : 0;
    final double shadowX = _isPressed ? 0 : appTheme.shadowOffset.dx;
    final double shadowY = _isPressed ? 0 : appTheme.shadowOffset.dy;

    const buttonLabel = 'Add Bots';

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
      child: MouseRegion(
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          // Move the button down-right when pressed
          transform: Matrix4.translationValues(xOffset, yOffset, 0),
          decoration: BoxDecoration(
            color: faceColor,
            shape: BoxShape
                .rectangle, // Always rectangle with radius, even for icon
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 2.0, // Thicker border for Neubrutalism feel
            ),
            boxShadow: [
              // Hard shadow (blurRadius: 0)
              BoxShadow(
                color: shadowColor,
                offset: Offset(shadowX, shadowY),
                blurRadius: 0,
              ),
            ],
          ),
          padding: widget.iconOnly
              ? EdgeInsets.zero // Centered by fixed size
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          // Fixed height 52 to match large touch targets, or 48 to match MainButton
          // MainButton is 48. Let's use 48 for consistency.
          height: 48,
          width: widget.iconOnly ? 48 : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/add_bot.svg',
                width: 20, // Slightly smaller icon inside the 48px box
                height: 20,
                colorFilter: ColorFilter.mode(
                  iconColor,
                  BlendMode.srcIn,
                ),
              ),
              if (!widget.iconOnly) ...[
                const SizedBox(width: 8),
                Text(
                  buttonLabel,
                  style: TextStyle(
                    color: iconColor,
                    fontFamily: AppFont.primaryOf(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
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
