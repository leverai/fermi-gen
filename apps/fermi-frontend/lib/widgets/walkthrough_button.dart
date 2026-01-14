import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A button that displays a light bulb Lottie animation for answer walkthroughs.
///
/// The animation loops continuously until tapped, then stops on tap.
/// Optionally, if [hasBeenViewed] is true, the animation shows static (no loop).
class WalkthroughButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;
  final bool hasBeenViewed;

  const WalkthroughButton({
    super.key,
    required this.onTap,
    this.size = 24.0,
    this.hasBeenViewed = false,
  });

  @override
  State<WalkthroughButton> createState() => _WalkthroughButtonState();
}

class _WalkthroughButtonState extends State<WalkthroughButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasTapped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _hasTapped = true;
    });
    _controller.stop();
    widget.onTap();
  }

  AppTheme get _appTheme => Theme.of(context).extension<AppTheme>()!;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(100),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Icon(Icons.help_outline,
              size: widget.size,
              color: _hasTapped ? _appTheme.border : _appTheme.warning),
        ),
      ),
    );
  }
}
