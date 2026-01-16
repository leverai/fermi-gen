import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:async';

enum Rank { first, second, third }

/// Visual style for showing rank icons. Used to pick an animation profile.
enum RankAnimationStyle {
  none, // static image (legacy)
  pop, // enlarge then slightly deflate
  sparkle, // subtle scale + fade-in with starburst
}

class RankWidget extends StatelessWidget {
  const RankWidget({
    super.key,
    required this.rank,
    this.animationStyle = RankAnimationStyle.none,
    this.show = true,
  });

  final Rank rank;
  final RankAnimationStyle animationStyle;
  final bool show;

  String get _imagePath {
    switch (rank) {
      case Rank.first:
        return 'assets/images/gold.png';
      case Rank.second:
        return 'assets/images/silver.png';
      case Rank.third:
        return 'assets/images/bronze.png';
    }
  }

  double get _badgeSize {
    switch (rank) {
      case Rank.first:
        return 30;
      case Rank.second:
        return 34;
      case Rank.third:
        return 34; // ~30% smaller than gold/silver
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget base = Image.asset(
      _imagePath,
      width: _badgeSize,
      height: _badgeSize,
    );

    switch (animationStyle) {
      case RankAnimationStyle.none:
        return base;
      case RankAnimationStyle.pop:
        return _PopIn(show: show, child: base);
      case RankAnimationStyle.sparkle:
        // Only add sparkles to gold (first place)
        if (rank == Rank.first) {
          return _SparkleIn(show: show, child: _PopIn(show: show, child: base));
        } else {
          // Silver and bronze get pop animation only, no sparkles
          return _PopIn(show: show, child: base);
        }
    }
  }
}

class _PopIn extends StatefulWidget {
  const _PopIn({required this.child, required this.show});
  final Widget child;
  final bool show;
  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.25)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 1.25, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40),
    ]).animate(_c);
    if (widget.show) {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _PopIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show != widget.show) {
      if (widget.show) {
        _c.forward(from: 0);
      } else {
        _c.reverse();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

// bounce animation removed per final design

class _SparkleIn extends StatefulWidget {
  const _SparkleIn({required this.child, required this.show});
  final Widget child;
  final bool show;
  @override
  State<_SparkleIn> createState() => _SparkleInState();
}

class _SparkleInState extends State<_SparkleIn> with TickerProviderStateMixin {
  late final AnimationController _c;
  late final AnimationController _spin;
  Timer? _sparkleTimer;
  bool _sparkleActive = false;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _spin =
        AnimationController(vsync: this, duration: const Duration(seconds: 6));
    if (widget.show) {
      _c.forward();
      _spin.repeat();
      _sparkleActive = true;
      _sparkleTimer?.cancel();
      _sparkleTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() {
          _sparkleActive = false;
        });
        _spin.stop();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _SparkleIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show != widget.show) {
      if (widget.show) {
        _c.forward(from: 0);
        _spin.repeat();
        _sparkleActive = true;
        _sparkleTimer?.cancel();
        _sparkleTimer = Timer(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          setState(() {
            _sparkleActive = false;
          });
          _spin.stop();
        });
      } else {
        _c.reverse();
        _spin.stop();
        _sparkleTimer?.cancel();
        _sparkleActive = false;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _spin.dispose();
    _sparkleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_c, _spin]),
      builder: (context, _) {
        final double t = _c.value;
        const double baseSize = 38.0; // matches image size
        const double center = baseSize / 2 + 1.0;
        const double yOffset = -3.0; // shift sparkles slightly upward

        // Build sparkle dots positioned in a ring around the medal (limited duration)
        final List<Widget> sparkles = <Widget>[];
        if (_sparkleActive) {
          const int count = 8;
          final double spinPhase = _spin.value; // 0..1 loop
          const double baseRadius = 22.0;
          final double appear = Curves.easeOut.transform(t.clamp(0.0, 1.0));
          for (int i = 0; i < count; i++) {
            final double angle = 2 * math.pi * (spinPhase + (i / count));
            final double twinkle = 0.6 +
                0.4 *
                    (0.5 +
                        0.5 *
                            math.sin(2 * math.pi * (spinPhase * 2 + i * 0.33)));
            final double starSize = 2.5 + 1.5 * twinkle;
            final double radius = baseRadius +
                1.0 * math.sin(2 * math.pi * (spinPhase + i / count));
            final double dx =
                center + math.cos(angle) * radius - (starSize / 2);
            final double dy =
                center + math.sin(angle) * radius - (starSize / 2) + yOffset;
            sparkles.add(Positioned(
              left: dx,
              top: dy,
              width: starSize,
              height: starSize,
              child: Opacity(
                opacity: (0.7 * twinkle * appear).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.6 * twinkle * appear),
                        blurRadius: 2 + 2 * twinkle,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ));
          }
        }

        // Do not animate the child here; child may already be a pop animation.
        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            ...sparkles,
          ],
        );
      },
    );
  }
}
