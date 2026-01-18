import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/colormap.dart';

/// A compact percentile widget that displays "Top X%" with animated digit wheels.
///
/// Features:
/// - Compact layout: height 24px, borderless, transparent background
/// - Shows "Top" (font 12, weight 400) + digit wheels (font 16, weight 600) + "%"
/// - Animated digit transitions when percentile changes
/// - Inverted color mapping: 1% = success (best), 99% = danger (worst)
/// - Optional visibility control without layout shifts
class PercentileWidget extends StatefulWidget {
  const PercentileWidget({
    super.key,
    required this.percentile,
    this.visible = true,
    this.animate = true,
  });

  /// Percentile value (0-100). Null hides the widget.
  final int? percentile;

  /// Whether the widget should be visible. When false, widget is transparent but maintains layout.
  final bool visible;

  /// Whether to animate digit transitions.
  final bool animate;

  @override
  State<PercentileWidget> createState() => _PercentileWidgetState();
}

class _PercentileWidgetState extends State<PercentileWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _previousPercentile;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _previousPercentile = widget.percentile;
  }

  @override
  void didUpdateWidget(PercentileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.percentile != oldWidget.percentile && widget.animate) {
      _previousPercentile = oldWidget.percentile;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Hide widget if percentile is null
    if (widget.percentile == null) {
      return const SizedBox.shrink();
    }

    // Get color: use the ORIGINAL target percentile (0-100)
    // percentile 99 (high score) -> success
    // percentile 1 (low score) -> danger
    final color = percentileToColor(widget.percentile!, theme: appTheme);

    return AnimatedOpacity(
      opacity: widget.visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: SizedBox(
        height: 24,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final startRaw = _previousPercentile ?? widget.percentile!;
            final endRaw = widget.percentile!;

            final currentRaw = widget.animate
                ? (startRaw + (_animation.value * (endRaw - startRaw))).round()
                : endRaw;

            final isBottom = currentRaw < 50;
            final label = isBottom ? 'bottom ' : 'top ';
            final displayValue = isBottom ? currentRaw : (100 - currentRaw);

            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // "Top"/"Bottom" text
                Text(
                  label,
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: appTheme.borderMuted,
                  ),
                ),
                // Animated digits
                Text(
                  '$displayValue',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                // "%" symbol
                Text(
                  '%',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: color,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
