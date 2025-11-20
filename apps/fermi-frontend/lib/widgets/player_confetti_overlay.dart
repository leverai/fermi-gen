import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:async';
import 'dart:math';

/// Displays a localized confetti animation for a player who achieved
/// the highest score on a question.
///
/// The confetti is clipped to the player widget bounds (100x160 area)
/// with low blast force and high drag to keep particles contained.
/// Uses small (3-6px) multicolor confetti particles.
/// Emits for 4 seconds, then lets particles naturally fall (~8 seconds total).
class PlayerConfettiOverlay extends StatefulWidget {
  const PlayerConfettiOverlay({
    super.key,
    this.onComplete,
  });

  /// Optional callback when the confetti animation completes.
  final VoidCallback? onComplete;

  @override
  State<PlayerConfettiOverlay> createState() => _PlayerConfettiOverlayState();
}

class _PlayerConfettiOverlayState extends State<PlayerConfettiOverlay> {
  late ConfettiController _controller;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();

    // Emit particles for 4 seconds, then let them naturally fall
    const emissionDuration = Duration(seconds: 4);
    _controller = ConfettiController(duration: emissionDuration);

    // Auto-start the confetti
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.play();
    });

    // Wait longer before cleanup to let particles fall naturally
    // 8 seconds = 4s emission + 4s for particles to fall with gravity
    const cleanupDelay = Duration(seconds: 8);
    _cleanupTimer = Timer(cleanupDelay, () {
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

  @override
  Widget build(BuildContext context) {
    // Clip confetti to widget bounds
    return ClipRect(
      child: Stack(
        children: [
          // Center confetti emitter
          Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirection: -pi / 2, // Up
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.15, // Higher drag to keep particles closer
              emissionFrequency: 0.03,
              numberOfParticles: 8,
              gravity: 0.2, // Faster fall to keep in bounds
              shouldLoop: false,
              // Standard multicolor confetti
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.orange,
                Colors.purple,
                Colors.pink,
                Colors.cyan,
              ],
              maxBlastForce: 5, // Much lower force to stay in widget
              minBlastForce: 2,
              // Smaller particle size (half the default ~10px)
              minimumSize: const Size(3, 3),
              maximumSize: const Size(6, 6),
            ),
          ),
        ],
      ),
    );
  }
}
