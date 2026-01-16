import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedSparkles extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const AnimatedSparkles({
    super.key,
    required this.color,
    this.size = 24.0,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<AnimatedSparkles> createState() => _AnimatedSparklesState();
}

class _AnimatedSparklesState extends State<AnimatedSparkles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedSparkles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _SparklesPainter(
              animation: _controller,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _SparklesPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _SparklesPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Star 1: Large, center-left
    _drawAnimatedStar(
      canvas: canvas,
      paint: paint,
      center: Offset(size.width * 0.4, size.height * 0.55),
      radius: size.width * 0.35,
      startTime: 0.0,
      endTime: 0.8,
      pulseCount: 2,
    );

    // Star 2: Medium, top-right
    _drawAnimatedStar(
      canvas: canvas,
      paint: paint,
      center: Offset(size.width * 0.8, size.height * 0.25),
      radius: size.width * 0.2,
      startTime: 0.15,
      endTime: 0.9,
      pulseCount: 2,
    );

    // Star 3: Small, bottom-right
    _drawAnimatedStar(
      canvas: canvas,
      paint: paint,
      center: Offset(size.width * 0.8, size.height * 0.75),
      radius: size.width * 0.15,
      startTime: 0.3,
      endTime: 1.0,
      pulseCount: 2,
    );
  }

  void _drawAnimatedStar({
    required Canvas canvas,
    required Paint paint,
    required Offset center,
    required double radius,
    required double startTime,
    required double endTime,
    int pulseCount = 1,
  }) {
    final double t = animation.value;

    if (t < startTime) return;

    double scale;
    if (t > endTime) {
      scale = 1.0;
    } else {
      final double localProgress = (t - startTime) / (endTime - startTime);

      if (localProgress < 0.2) {
        scale = Curves.elasticOut.transform(localProgress / 0.2);
      } else {
        final double pulseProgress = (localProgress - 0.2) / 0.8;
        final double angle = pulseProgress * math.pi * 2 * pulseCount;
        final double amplitude = 0.3 * (1 - pulseProgress);
        scale = 1.0 + math.sin(angle) * amplitude;
      }
    }

    _drawStarShape(canvas, paint, center, radius, scale);
  }

  void _drawStarShape(Canvas canvas, Paint paint, Offset center,
      double maxRadius, double scale) {
    if (scale <= 0) return;

    final double r = maxRadius * scale;
    final double innerR = r * 0.4;

    final Path path = Path();
    path.moveTo(center.dx, center.dy - r);
    path.lineTo(center.dx + innerR, center.dy - innerR);
    path.lineTo(center.dx + r, center.dy);
    path.lineTo(center.dx + innerR, center.dy + innerR);
    path.lineTo(center.dx, center.dy + r);
    path.lineTo(center.dx - innerR, center.dy + innerR);
    path.lineTo(center.dx - r, center.dy);
    path.lineTo(center.dx - innerR, center.dy - innerR);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklesPainter oldDelegate) {
    return oldDelegate.animation.value != animation.value ||
        oldDelegate.color != color;
  }
}
