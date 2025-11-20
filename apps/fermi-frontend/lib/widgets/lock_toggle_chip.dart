import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// A compact icon that toggles between locked (private) and unlocked (public) states.
/// Shows a tooltip with the current state ("Private" or "Public") when tapped.
class LockToggleChip extends StatefulWidget {
  const LockToggleChip({
    super.key,
    required this.isLocked,
    required this.onToggle,
  });

  final bool isLocked;
  final VoidCallback onToggle;

  @override
  State<LockToggleChip> createState() => _LockToggleChipState();
}

class _LockToggleChipState extends State<LockToggleChip> {
  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Color changes based on selection
    // When selected (locked): use secondary color
    // When not selected: use border color
    final color = widget.isLocked ? appTheme.primary : appTheme.borderMuted;
    final label = widget.isLocked ? 'Private' : 'Public';
    final icon = widget.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded;

    return Material(
      type: MaterialType.transparency,
      child: Tooltip(
        message: label,
        preferBelow: false, // Show tooltip above the button
        verticalOffset: 18 + 24, // Position tooltip higher above the widget
        triggerMode: TooltipTriggerMode.tap, // Show on tap
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              // ignore: deprecated_member_use
              appTheme.bgLight.withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        enableTapToDismiss: true,
        onTriggered: () {
          // Toggle when tooltip is triggered
          widget.onToggle();
        },
        textStyle: AppFont.primaryTextStyle(
          context,
          fontSize: 14,
          fontWeight: widget.isLocked ? FontWeight.w500 : FontWeight.w400,
          color: appTheme.textMuted,
        ).copyWith(letterSpacing: 0.8),
        child: SizedBox(
          width: 28,
          height: 48,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                icon,
                key: ValueKey<bool>(widget.isLocked),
                size: 36,
                color: color,
                weight: 100,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
