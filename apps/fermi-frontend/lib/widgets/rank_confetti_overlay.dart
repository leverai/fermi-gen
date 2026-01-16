import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/services/confetti_sound_service.dart';

/// Displays a full-screen confetti animation for top 3 players.
///
/// The confetti fires in synchronized bursts with sound effects:
/// - Crowd cheering plays throughout the animation
/// - Pop sounds play with each confetti burst
///
/// The animation consists of multiple timed bursts over ~3 seconds,
/// then particles fall naturally with gravity for another ~6 seconds.
/// Total animation: 9 seconds to match the crowd cheering sound.
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
  final List<_ConfettiBurst> _bursts = [];
  final List<Timer> _timers = [];
  final ConfettiSoundService _soundService = ConfettiSoundService();

  // Burst schedule: [delay in ms, position (0=center, 1=left, 2=right)]
  // Creates a satisfying sequence of explosions over ~3 seconds
  static const List<List<int>> _burstSchedule = [
    [0, 0], // Center burst immediately
    [150, 1], // Left burst
    [300, 2], // Right burst
    [600, 0], // Center again
    [900, 1], // Left
    [900, 2], // Right (simultaneous sides)
    [1500, 0], // Center
    [2200, 1], // Left
  ];

  @override
  void initState() {
    super.initState();
    _initializeBursts();
    _scheduleBursts();
    _scheduleCleanup();
  }

  void _initializeBursts() {
    // Create a controller for each scheduled burst
    for (int i = 0; i < _burstSchedule.length; i++) {
      // Very short duration - just one burst of particles
      final controller = ConfettiController(
        duration: const Duration(milliseconds: 100),
      );
      final position = _burstSchedule[i][1];
      _bursts.add(_ConfettiBurst(
        controller: controller,
        position: position,
      ));
    }
  }

  void _scheduleBursts() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize sound players first
      await _soundService.initialize();

      // Start crowd cheering immediately
      _soundService.startCheering();

      // Schedule each burst
      for (int i = 0; i < _burstSchedule.length; i++) {
        final delay = _burstSchedule[i][0];
        final timer = Timer(Duration(milliseconds: delay), () {
          if (mounted) {
            _bursts[i].controller.play();
            _soundService.playPop();
          }
        });
        _timers.add(timer);
      }
    });
  }

  void _scheduleCleanup() {
    // Total animation time: 9 seconds to match crowd cheering sound
    // Last burst at 3000ms + 6s for particles to fall
    const cleanupDelay = Duration(seconds: 9);
    final timer = Timer(cleanupDelay, () {
      if (mounted) {
        _soundService.stop();
        widget.onComplete?.call();
      }
    });
    _timers.add(timer);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    for (final burst in _bursts) {
      burst.controller.dispose();
    }
    _soundService.stop();
    super.dispose();
  }

  _BurstConfig _getConfigForRank(int rank, AppTheme theme) {
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

    switch (rank) {
      case 1:
        rankColor = theme.gold;
        particles = 10;
        break;
      case 2:
        rankColor = theme.silver;
        particles = 7;
        break;
      case 3:
        rankColor = theme.bronze;
        particles = 5;
        break;
      default:
        rankColor = Colors.grey;
        particles = 12;
    }

    // Mix happy colors with rank color (25% rank color)
    final int rankColorsCount = (happyColors.length / 3).ceil();
    final colors = [
      ...happyColors,
      ...List.generate(rankColorsCount, (_) => rankColor),
    ];

    return _BurstConfig(colors: colors, numberOfParticles: particles);
  }

  Alignment _getAlignmentForPosition(int position) {
    switch (position) {
      case 1:
        return Alignment.bottomLeft;
      case 2:
        return Alignment.bottomRight;
      default:
        return Alignment.bottomCenter;
    }
  }

  double _getBlastDirectionForPosition(int position) {
    switch (position) {
      case 1:
        return -.45 * pi; // Top-right
      case 2:
        return -.55 * pi; // Top-left
      default:
        return -pi / 2; // Straight up
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show confetti for top 3 ranks
    if (widget.rank < 1 || widget.rank > 3) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context).extension<AppTheme>()!;
    final config = _getConfigForRank(widget.rank, theme);

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: _bursts.map((burst) {
          return Align(
            alignment: _getAlignmentForPosition(burst.position),
            child: ConfettiWidget(
              confettiController: burst.controller,
              blastDirection: _getBlastDirectionForPosition(burst.position),
              blastDirectionality: BlastDirectionality.directional,
              particleDrag: 0.015,
              emissionFrequency: 1.0, // 100% - emit all particles immediately
              numberOfParticles: config.numberOfParticles,
              gravity: 0.05,
              shouldLoop: false,
              colors: config.colors,
              maxBlastForce: burst.position == 0 ? 60 : 80,
              minBlastForce: burst.position == 0 ? 30 : 40,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Represents a single confetti burst with its controller and position.
class _ConfettiBurst {
  _ConfettiBurst({required this.controller, required this.position});
  final ConfettiController controller;
  final int position; // 0=center, 1=left, 2=right
}

/// Configuration for confetti bursts based on rank.
class _BurstConfig {
  const _BurstConfig({required this.colors, required this.numberOfParticles});
  final List<Color> colors;
  final int numberOfParticles;
}
