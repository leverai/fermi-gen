import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/animated_sparkles.dart';

class WalkthroughButton extends StatefulWidget {
  final VoidCallback onTap;
  final Duration spinDuration;
  final Duration sparkleDuration;
  final double size;

  const WalkthroughButton({
    super.key,
    required this.onTap,
    this.spinDuration = const Duration(milliseconds: 1500),
    this.sparkleDuration = const Duration(seconds: 2),
    this.size = 20.0,
  });

  @override
  State<WalkthroughButton> createState() => _WalkthroughButtonState();
}

class _WalkthroughButtonState extends State<WalkthroughButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: widget.spinDuration,
    );

    _spinAnimation = CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeInOutBack,
    );

    _spinController.forward();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(WalkthroughButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spinDuration != widget.spinDuration) {
      _spinController.duration = widget.spinDuration;
    }
  }

  @override
  Widget build(BuildContext context) {
    // We access theme here to style the container
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(100),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            RotationTransition(
              turns: _spinAnimation,
              child: AnimatedSparkles(
                color: appTheme.primary,
                size: widget.size,
                duration: widget.sparkleDuration,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
