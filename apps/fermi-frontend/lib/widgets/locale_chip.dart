import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// A simple chip that displays "U.S." for the US locale.
/// Matches the 60x72 size of other answer area elements.
/// Text color changes based on selection state (highlight when selected).
class LocaleChip extends StatefulWidget {
  const LocaleChip({
    super.key,
    required this.currentLocale,
    required this.onToggle,
  });

  final String currentLocale;
  final ValueChanged<String> onToggle;

  @override
  State<LocaleChip> createState() => _LocaleChipState();
}

class _LocaleChipState extends State<LocaleChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Play bounce animation
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Toggle locale: US <-> EU
    final newLocale = widget.currentLocale.toUpperCase() == 'US' ? 'EU' : 'US';
    widget.onToggle(newLocale);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final bool isUS = widget.currentLocale.toUpperCase() == 'US';
    final Color textColor = isUS ? appTheme.highlight : appTheme.borderMuted;
    final FontWeight textWeight = isUS ? FontWeight.w900 : FontWeight.w400;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 60,
        height: 72,
        decoration: BoxDecoration(
          color: appTheme.bg,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(8.0),
            splashColor:
                // ignore: deprecated_member_use
                appTheme.primary.withOpacity(0.12),
            highlightColor:
                // ignore: deprecated_member_use
                appTheme.primary.withOpacity(0.08),
            child: Center(
              child: Text(
                'U.S',
                style: AppFont.secondaryTextStyle(
                  context,
                  fontSize: 16,
                  fontWeight: textWeight,
                  color: textColor,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
