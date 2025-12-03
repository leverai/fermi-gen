import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'player_widget.dart';

/// A circular progress ring that wraps player avatar content.
///
/// Features:
/// - Uses CircularProgressIndicator for smooth progress animation
/// - Inverts progress for countdown (100→0 display)
/// - Ring color indicates self vs others (info for self, border for others)
/// - Gap color indicates host status (primary for host, transparent otherwise)
/// - Maintains consistent dimensions with transparent background
class PlayerRingProgress extends StatelessWidget {
  const PlayerRingProgress({
    super.key,
    required this.child,
    required this.ringState,
    required this.ringProgress,
    required this.isSelf,
    required this.isHost,
  });

  final Widget child;
  final RingState ringState;
  final double ringProgress; // 0.0-1.0 from tracker
  final bool isSelf;
  final bool isHost;

  // Ring dimensions
  static const double avatarSize = 70.0;
  static const double ringGap = 4.0;
  static const double ringThickness = 6.0;
  static const double totalSize =
      avatarSize + (ringGap * 2) + (ringThickness * 2);

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Compute ring color based on state
    final Color ringColor = _getRingColor(appTheme);

    // Compute display progress (invert for countdown)
    final double displayProgress = ringState == RingState.countdown
        ? (1.0 - ringProgress) // Invert: 100→0
        : 1.0; // Completed/Review: show full

    // Get gap color: host uses primary, others use transparent
    final Color ringGapColor = isHost ? appTheme.secondary : Colors.transparent;
    // ignore: deprecated_member_use
    final Color trackColor = ringColor.withOpacity(0.2);

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(totalSize),
            painter: _RingPainter(
              progress: displayProgress.clamp(0.0, 1.0),
              progressColor: ringColor,
              trackColor: trackColor,
              thickness: ringThickness,
            ),
          ),
          // Gap container (creates spacing between ring and avatar)
          Container(
            width: avatarSize + (ringGap * 2),
            height: avatarSize + (ringGap * 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ringGapColor,
            ),
            child: Center(
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRingColor(AppTheme appTheme) {
    switch (ringState) {
      case RingState.countdown:
        // Ring color: self uses info, others use border
        return isSelf ? appTheme.primary : appTheme.borderMuted;

      case RingState.completed:
        // Completed: self uses info, others use success (green)
        return isSelf ? appTheme.primary : appTheme.success;

      case RingState.review:
        // Ring color: self uses info, others use border
        return isSelf ? appTheme.primary : appTheme.borderMuted;
    }
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
    required this.thickness,
  });

  final double progress;
  final Color progressColor;
  final Color trackColor;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.width - thickness) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final Paint progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    // Draw full track to show remaining time background.
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);

    final double clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress <= 0) {
      return;
    }

    final double sweepAngle = math.pi * 2 * clampedProgress;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        progressColor != oldDelegate.progressColor ||
        trackColor != oldDelegate.trackColor ||
        thickness != oldDelegate.thickness;
  }
}
