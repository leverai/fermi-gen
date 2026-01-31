import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

/// Displays a gentle confetti animation for top PA card achievements.
///
/// This is a simpler, shorter confetti effect compared to RankConfettiOverlay:
/// - No sound effects
/// - Shorter duration (4 seconds total)
/// - Gentle falling particles (no explosive bursts)
/// - Themed colors based on tier
class PACardConfettiOverlay extends StatefulWidget {
  const PACardConfettiOverlay({
    super.key,
    required this.themeColor,
    this.onComplete,
  });

  /// The theme color for the PA card (used to tint confetti).
  final Color themeColor;

  /// Optional callback when the confetti animation completes.
  final VoidCallback? onComplete;

  @override
  State<PACardConfettiOverlay> createState() => _PACardConfettiOverlayState();
}

class _PACardConfettiOverlayState extends State<PACardConfettiOverlay> {
  late ConfettiController _controller;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();

    // Emit particles for 2 seconds
    _controller = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    // Auto-start the confetti
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.play();
    });

    // Total animation: 4 seconds (2s emission + 2s for particles to fall)
    _cleanupTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<Color> _getColors() {
    // Mix of vibrant colors with the theme color
    return [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
      widget.themeColor,
      widget.themeColor,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _controller,
          blastDirection: pi / 2, // Down (falling from top)
          blastDirectionality: BlastDirectionality.explosive,
          particleDrag: 0.05,
          emissionFrequency: 0.05,
          numberOfParticles: 5,
          gravity: 0.15,
          shouldLoop: false,
          colors: _getColors(),
          maxBlastForce: 10,
          minBlastForce: 5,
          minimumSize: const Size(5, 5),
          maximumSize: const Size(10, 10),
        ),
      ),
    );
  }
}
