import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

/// Displays a full-screen confetti animation for top 3 players.
///
/// The confetti style varies by rank:
/// - 1st place: Gold confetti with highest density
/// - 2nd place: Silver confetti with medium density
/// - 3rd place: Bronze confetti with lower density
///
/// The animation emits particles for 6 seconds, then lets them naturally
/// fall off screen with gravity. The widget is removed after ~12 seconds
/// total to allow the particles to fall naturally.
class RankConfettiOverlay extends StatefulWidget {
  const RankConfettiOverlay({
    super.key,
    required this.rank,
    this.onComplete,
  });

  /// The player's rank (1, 2, or 3). Other values are ignored.
  final int rank;

  /// Optional callback when the confetti animation completes.
  final VoidCallback? onComplete;

  @override
  State<RankConfettiOverlay> createState() => _RankConfettiOverlayState();
}

class _RankConfettiOverlayState extends State<RankConfettiOverlay> {
  late ConfettiController _controllerCenter;
  late ConfettiController _controllerLeft;
  late ConfettiController _controllerRight;

  @override
  void initState() {
    super.initState();

    // Emit particles for 6 seconds (increased by 4s from original 2s), then let them naturally fall off screen
    const emissionDuration = Duration(seconds: 6);
    _controllerCenter = ConfettiController(duration: emissionDuration);
    _controllerLeft = ConfettiController(duration: emissionDuration);
    _controllerRight = ConfettiController(duration: emissionDuration);

    // Auto-start the confetti
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controllerCenter.play();
      _controllerLeft.play();
      _controllerRight.play();
    });

    // Wait longer before cleanup to let particles fall naturally off screen
    // 12 seconds = 6s emission + 6s for particles to fall with gravity
    const cleanupDelay = Duration(seconds: 12);
    Future.delayed(cleanupDelay, () {
      if (mounted) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controllerCenter.dispose();
    _controllerLeft.dispose();
    _controllerRight.dispose();
    super.dispose();
  }

  /// Returns the confetti configuration based on rank.
  _RankConfettiConfig _getConfigForRank(int rank) {
    switch (rank) {
      case 1:
        return const _RankConfettiConfig(
          colors: [
            Color(0xFFFFD700), // Gold
            Color(0xFFFFC700),
            Color(0xFFFFB700),
            Color(0xFFFFAA00),
            Color(0xFFFF9500),
          ],
          numberOfParticles: 30,
          emissionFrequency: 0.01,
          gravity: 0.1,
        );
      case 2:
        return const _RankConfettiConfig(
          colors: [
            Color(0xFFC0C0C0), // Silver
            Color(0xFFD3D3D3),
            Color(0xFFB8B8B8),
            Color(0xFFA9A9A9),
            Color(0xFF9E9E9E),
          ],
          numberOfParticles: 20,
          emissionFrequency: 0.015,
          gravity: 0.12,
        );
      case 3:
        return const _RankConfettiConfig(
          colors: [
            Color(0xFFCD7F32), // Bronze
            Color(0xFFB87333),
            Color(0xFFA0522D),
            Color(0xFF8B4513),
            Color(0xFF704214),
          ],
          numberOfParticles: 15,
          emissionFrequency: 0.02,
          gravity: 0.15,
        );
      default:
        // Fallback (shouldn't happen)
        return const _RankConfettiConfig(
          colors: [Colors.grey],
          numberOfParticles: 10,
          emissionFrequency: 0.02,
          gravity: 0.15,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show confetti for top 3 ranks
    if (widget.rank < 1 || widget.rank > 3) {
      return const SizedBox.shrink();
    }

    final config = _getConfigForRank(widget.rank);

    // Explicitly fill the entire available space to ensure confetti covers full screen
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Center confetti - positioned at absolute top center
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _controllerCenter,
              blastDirection: pi / 2, // Down
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: config.emissionFrequency,
              numberOfParticles: config.numberOfParticles,
              gravity: config.gravity,
              shouldLoop: false,
              colors: config.colors,
              maxBlastForce: 20,
              minBlastForce: 10,
            ),
          ),
          // Left side confetti - positioned at absolute left center
          Align(
            alignment: Alignment.centerLeft,
            child: ConfettiWidget(
              confettiController: _controllerLeft,
              blastDirection: 0, // Right
              blastDirectionality: BlastDirectionality.directional,
              particleDrag: 0.05,
              emissionFrequency: config.emissionFrequency,
              numberOfParticles: (config.numberOfParticles * 0.6).round(),
              gravity: config.gravity,
              shouldLoop: false,
              colors: config.colors,
              maxBlastForce: 15,
              minBlastForce: 8,
            ),
          ),
          // Right side confetti - positioned at absolute right center
          Align(
            alignment: Alignment.centerRight,
            child: ConfettiWidget(
              confettiController: _controllerRight,
              blastDirection: pi, // Left
              blastDirectionality: BlastDirectionality.directional,
              particleDrag: 0.05,
              emissionFrequency: config.emissionFrequency,
              numberOfParticles: (config.numberOfParticles * 0.6).round(),
              gravity: config.gravity,
              shouldLoop: false,
              colors: config.colors,
              maxBlastForce: 15,
              minBlastForce: 8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Configuration for confetti based on rank.
class _RankConfettiConfig {
  const _RankConfettiConfig({
    required this.colors,
    required this.numberOfParticles,
    required this.emissionFrequency,
    required this.gravity,
  });

  final List<Color> colors;
  final int numberOfParticles;
  final double emissionFrequency;
  final double gravity;
}
