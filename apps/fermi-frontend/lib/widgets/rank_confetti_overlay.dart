import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import 'package:fermi_frontend/theme/app_theme.dart';

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
  _RankConfettiConfig _getConfigForRank(int rank, AppTheme theme) {
    // Standard vibrant "happy" colors
    final happyColors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
      Colors.cyanAccent,
      theme.primary,
      theme.secondary,
    ];

    Color rankColor;
    int particles;
    double frequency;
    double gravity;

    switch (rank) {
      case 1:
        rankColor = theme.gold;
        particles = 30;
        frequency = 0.02;
        gravity = 0.1;
        break;
      case 2:
        rankColor = theme.silver;
        particles = 20;
        frequency = 0.02;
        gravity = 0.1;
        break;
      case 3:
        rankColor = theme.bronze;
        particles = 15;
        frequency = 0.02;
        gravity = 0.1;
        break;
      default:
        rankColor = Colors.grey;
        particles = 10;
        frequency = 0.02;
        gravity = 0.1;
    }

    // Per requirement: The gold/silver/bronze confettis should take 4th of the total confetti.
    // To achieve 25% rank color, we mix happyColors with rankColor in 3:1 ratio.
    // Since happyColors has 10 elements, we add 10/3 ~ 3 or 4 elements of rankColor.
    // Specifically, if we want rankColor to be 1/4, and happyColors is 3/4:
    // happyColors.length / 3 = rankColorsCount
    final int rankColorsCount = (happyColors.length / 3).ceil();
    final colors = [
      ...happyColors,
      ...List.generate(rankColorsCount, (_) => rankColor),
    ];

    return _RankConfettiConfig(
      colors: colors,
      numberOfParticles: particles,
      emissionFrequency: frequency,
      gravity: gravity,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show confetti for top 3 ranks
    if (widget.rank < 1 || widget.rank > 3) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context).extension<AppTheme>()!;
    final config = _getConfigForRank(widget.rank, theme);

    // Explicitly fill the entire available space to ensure confetti covers full screen
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Center confetti - positioned at bottom center firing up
          Align(
            alignment: Alignment.bottomCenter,
            child: ConfettiWidget(
              confettiController: _controllerCenter,
              blastDirection: -pi / 2, // Straight up
              blastDirectionality: BlastDirectionality.directional,
              particleDrag: 0.015,
              emissionFrequency: config.emissionFrequency,
              numberOfParticles: config.numberOfParticles,
              gravity: config.gravity,
              shouldLoop: false,
              colors: config.colors,
              maxBlastForce: 60,
              minBlastForce: 30,
            ),
          ),
          // Left side confetti - positioned at bottom left firing top-right
          Align(
            alignment: Alignment.bottomLeft,
            child: ConfettiWidget(
              confettiController: _controllerLeft,
              blastDirection: -pi / 3, // Top-right
              blastDirectionality: BlastDirectionality.directional,
              particleDrag: 0.015,
              emissionFrequency: config.emissionFrequency,
              numberOfParticles: (config.numberOfParticles * 0.8).round(),
              gravity: config.gravity,
              shouldLoop: false,
              colors: config.colors,
              maxBlastForce: 80,
              minBlastForce: 40,
            ),
          ),
          // Right side confetti - positioned at bottom right firing top-left
          Align(
            alignment: Alignment.bottomRight,
            child: ConfettiWidget(
              confettiController: _controllerRight,
              blastDirection: -2 * pi / 3, // Top-left
              blastDirectionality: BlastDirectionality.directional,
              particleDrag: 0.015,
              emissionFrequency: config.emissionFrequency,
              numberOfParticles: (config.numberOfParticles * 0.8).round(),
              gravity: config.gravity,
              shouldLoop: false,
              colors: config.colors,
              maxBlastForce: 80,
              minBlastForce: 40,
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
