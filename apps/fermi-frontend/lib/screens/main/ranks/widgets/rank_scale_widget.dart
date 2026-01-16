// ignore_for_file: deprecated_member_use

import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';

class RankScaleWidget extends StatelessWidget {
  const RankScaleWidget({
    super.key,
    required this.currentRank,
    required this.playerPercentile,
    required this.allRanks,
  });

  final RankDefinition currentRank;
  final int playerPercentile;
  final List<RankDefinition> allRanks;

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SizedBox(
        height: 80,
        width: double.infinity,
        child: CustomPaint(
          painter: _ScalePainter(
            currentRank: currentRank,
            playerPercentile: playerPercentile,
            allRanks: allRanks,
            appTheme: appTheme,
            context: context,
          ),
        ),
      ),
    );
  }
}

class _ScalePainter extends CustomPainter {
  final RankDefinition currentRank;
  final int playerPercentile;
  final List<RankDefinition> allRanks;
  final AppTheme appTheme;
  final BuildContext context;

  _ScalePainter({
    required this.currentRank,
    required this.playerPercentile,
    required this.allRanks,
    required this.appTheme,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Configuration
    const double barHeight = 6.0;
    final double barY = size.height / 2;
    final Paint activePaint = Paint()
      ..color = appTheme.primary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barHeight;
    final Paint inactivePaint = Paint()
      ..color = appTheme.borderMuted.withOpacity(0.5)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barHeight;
    final Paint markerPaint = Paint()
      ..color = appTheme.textMuted
      ..style = PaintingStyle.fill;
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw background bar (full width)
    canvas.drawLine(
      Offset(0, barY),
      Offset(size.width, barY),
      inactivePaint,
    );

    // Identify range for current rank
    // Find Next rank percentile for end of range
    int startPercentile = currentRank.minPercentile;
    int endPercentile = 100;

    // Safety check if we are at the last rank
    // In our list 5 is highest, minPerc 98. Next is none. So 100.
    // For others, e.g. Rank 1 (0%), next is Rank 2 (40%).
    for (var r in allRanks) {
      if (r.id == currentRank.id + 1) {
        endPercentile = r.minPercentile;
        break;
      }
    }

    // Convert percentile to X coordinate
    double getX(int p) {
      return (p / 100) * size.width;
    }

    // Draw Active Segment (Range of the current rank)
    double startX = getX(startPercentile);
    double endX = getX(endPercentile);

    // We want the active segment to look nice, maybe slightly thicker or just colored
    canvas.drawLine(
      Offset(startX, barY),
      Offset(endX, barY),
      activePaint,
    );

    // Draw boundary markers and labels
    final thresholds = [0, 40, 75, 90, 98, 100];
    for (var t in thresholds) {
      double x = getX(t);
      // Skip 0 and 100 markers if they are too close to edges or redundant?
      // Draw small vertical line
      canvas.drawCircle(
          Offset(x, barY), 4, Paint()..color = appTheme.bg); // clearer
      canvas.drawCircle(Offset(x, barY), 2, markerPaint);

      // Draw text below?
      // Only draw text for start/end of current rank to avoid clutter?
      // Or draw all small?
      // Requirement says "showing key percentages".

      bool isBoundary = t == startPercentile || t == endPercentile;
      if (isBoundary) {
        String label = '$t';
        if (startPercentile == 98) {
          if (t == 100) continue; // Skip 100% text to avoid overlap
          if (t == 98) label = '98 100';
        }

        textPainter.text = TextSpan(
          text: label,
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: activePaint.color, // Highlight boundaries of current rank
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, barY + 12));
      }
    }

    // Draw Player Marker ("You")
    double playerX = getX(playerPercentile);

    // Draw "You" bubble above
    final Paint bubblePaint = Paint()..color = appTheme.secondary;

    // Triangle pointing down
    Path trianglePath = Path();
    trianglePath.moveTo(playerX, barY - 6);
    trianglePath.lineTo(playerX - 6, barY - 14);
    trianglePath.lineTo(playerX + 6, barY - 14);
    trianglePath.close();
    canvas.drawPath(trianglePath, bubblePaint);

    // Bubble Text "You" or "$p%"
    textPainter.text = TextSpan(
      text: '$playerPercentile',
      style: AppFont.primaryTextStyle(
        context,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: appTheme.bg,
      ),
    );
    textPainter.layout();

    // Draw bubble background (rounded rect)
    double pad = 6;
    RRect bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(playerX, barY - 22),
        width: textPainter.width + pad * 2,
        height: textPainter.height + pad,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(bubbleRect, bubblePaint);

    textPainter.paint(
      canvas,
      Offset(
          playerX - textPainter.width / 2, barY - 22 - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _ScalePainter oldDelegate) {
    return oldDelegate.currentRank != currentRank ||
        oldDelegate.playerPercentile != playerPercentile ||
        oldDelegate.appTheme != appTheme;
  }
}
