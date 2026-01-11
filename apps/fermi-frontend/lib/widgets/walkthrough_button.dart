import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

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

  /// Determines if the animation should loop.
  bool get _shouldAnimate => !widget.hasBeenViewed && !_hasTapped;

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
          child: Lottie.asset(
            'assets/lotties/thinking.json',
            controller: _controller,
            onLoaded: (composition) {
              _controller.duration = composition.duration;
              if (_shouldAnimate) {
                _controller.repeat();
              } else {
                // Show static first frame
                _controller.value = 0.0;
              }
            },
            fit: BoxFit.fitHeight,
          ),
        ),
      ),
    );
  }
}
