import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/colormap.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// A simple text widget that displays: "Your guesses are better than XX% of players."
/// The percentile value animates when it changes and uses color scaling.
/// Supports show/hide animation with a rolling effect (slides down and fades out when hiding).
///
/// **Visibility behavior:**
/// - Automatically hides when [percentile] is `null` or `0`
/// - The [visible] prop can be used to override this behavior (e.g., for custom conditions)
/// - Final visibility = (percentile != null && percentile > 0) && visible
class SimplePercentileText extends StatefulWidget {
  /// Percentile value (0–100). When `null` or `0`, the widget will automatically hide.
  final int? percentile;

  /// Controls show/hide animation. When `true`, the widget will show if percentile is valid (> 0).
  /// When `false`, the widget will hide regardless of percentile value.
  /// Defaults to `true`.
  final bool visible;

  /// Custom prefix text (default: "Your answers beat  ")
  final String? prefixText;

  /// Custom suffix text (default: "  of players.")
  final String? suffixText;

  const SimplePercentileText({
    super.key,
    this.percentile,
    this.visible = true,
    this.prefixText,
    this.suffixText,
  }) : assert(
          percentile == null || (percentile >= 0 && percentile <= 100),
          'percentile must be null or between 0 and 100',
        );

  @override
  State<SimplePercentileText> createState() => _SimplePercentileTextState();
}

class _SimplePercentileTextState extends State<SimplePercentileText>
    with TickerProviderStateMixin {
  // Height for the percentage digits and symbol to avoid clipping with different fonts
  static const double _percentageHeight = 24.0;
  static const double _wheelWidth = 14.0;
  // Font size range: 14 at percentile 0, 24 at percentile 100
  static const double _minFontSize = 14.0;
  static const double _maxFontSize = 24.0;
  // Animation duration for color and font size changes
  static const Duration _animationDuration = Duration(milliseconds: 450);

  late FixedExtentScrollController _tensController;
  late FixedExtentScrollController _onesController;
  late AnimationController _visibilityController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  double _currentFontSize = _minFontSize;

  /// Computes effective visibility: hides when percentile is null or 0,
  /// unless explicitly overridden via visible prop.
  bool get _effectiveVisible {
    final hasValidPercentile =
        widget.percentile != null && widget.percentile! > 0;
    return hasValidPercentile && widget.visible;
  }

  @override
  void initState() {
    super.initState();
    final int initial = (widget.percentile ?? 0).clamp(0, 100);
    final _Digits d = _decompose(initial);
    _tensController = FixedExtentScrollController(initialItem: d.tens);
    _onesController = FixedExtentScrollController(initialItem: d.ones);
    _currentFontSize = _fontSizeFromPercentile(initial);

    // Initialize visibility animation controller
    _visibilityController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Slide animation: rolls up when appearing (1.0 -> 0.0), rolls down when hiding (0.0 -> 1.0)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0), // Start below (rolled down)
      end: Offset.zero, // End at normal position
    ).animate(CurvedAnimation(
      parent: _visibilityController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _visibilityController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    // Set initial visibility state
    if (_effectiveVisible) {
      _visibilityController.value = 1.0;
    }
  }

  /// Helper to compute effective visibility for a given widget instance.
  static bool _computeEffectiveVisible(int? percentile, bool visible) {
    final hasValidPercentile = percentile != null && percentile > 0;
    return hasValidPercentile && visible;
  }

  @override
  void didUpdateWidget(covariant SimplePercentileText oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle visibility changes (check effective visibility which accounts for null/0 percentile)
    final bool oldEffectiveVisible = _computeEffectiveVisible(
      oldWidget.percentile,
      oldWidget.visible,
    );
    if (_effectiveVisible != oldEffectiveVisible) {
      if (_effectiveVisible) {
        _visibilityController.forward();
      } else {
        _visibilityController.reverse();
      }
    }

    // Handle percentile value changes
    final int newVal = (widget.percentile ?? 0).clamp(0, 100);
    final int oldVal = (oldWidget.percentile ?? 0).clamp(0, 100);
    if (newVal != oldVal) {
      final _Digits d = _decompose(newVal);
      _tensController.animateToItem(
        d.tens,
        duration: _animationDuration,
        curve: Curves.easeInOutCubic,
      );
      _onesController.animateToItem(
        d.ones,
        duration: _animationDuration,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  _Digits _decompose(int value) {
    final v = value.clamp(0, 100);
    final int tens = (v ~/ 10) % 10;
    final int ones = v % 10;
    return _Digits(tens: tens, ones: ones);
  }

  /// Calculates font size based on percentile (14 at 0, 24 at 100)
  static double _fontSizeFromPercentile(int percentile) {
    final double t = percentile.clamp(0, 100) / 100.0;
    return _minFontSize + (t * (_maxFontSize - _minFontSize));
  }

  @override
  void dispose() {
    _tensController.dispose();
    _onesController.dispose();
    _visibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int clamped = (widget.percentile ?? 0).clamp(0, 100);
    final Color targetColor = percentileToColor(clamped);
    final double targetFontSize = _fontSizeFromPercentile(clamped);

    return ClipRect(
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: _currentFontSize, end: targetFontSize),
            duration: _animationDuration,
            curve: Curves.easeInOutCubic,
            onEnd: () {
              setState(() {
                _currentFontSize = targetFontSize;
              });
            },
            builder: (context, animatedFontSize, _) {
              return TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: targetColor),
                duration: _animationDuration,
                curve: Curves.easeInOutCubic,
                builder: (context, animatedColor, _) {
                  final Color color = animatedColor ?? targetColor;
                  final AppTheme appTheme =
                      Theme.of(context).extension<AppTheme>() ??
                          AppTheme.defaultTheme();
                  // Static text uses border color
                  final Color staticTextColor = appTheme.border;

                  final String prefix =
                      widget.prefixText ?? 'Your answers beat  ';
                  final String suffix = widget.suffixText ?? '  of players.';
                  final String semanticsLabel =
                      widget.prefixText != null || widget.suffixText != null
                          ? '$prefix$clamped%$suffix'
                          : 'Your answers beat $clamped of players.';

                  return Semantics(
                    label: semanticsLabel,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildStaticText(prefix, staticTextColor),
                        _buildAnimatedDigits(color, animatedFontSize),
                        _buildPercentSymbol(color, animatedFontSize),
                        _buildStaticText(suffix, staticTextColor),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStaticText(String text, Color color) {
    return Text(
      text,
      style: AppFont.primaryTextStyle(
        context,
        fontSize: 14,
        fontWeight: FontWeight.w300,
        color: color,
        height: 1.0,
      ).copyWith(letterSpacing: 0.6),
    );
  }

  Widget _buildPercentSymbol(Color color, double fontSize) {
    final TextStyle percentStyle = AppFont.secondaryTextStyle(
      context,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.0,
    );

    return SizedBox(
      height: _percentageHeight - 1,
      child: ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Text(
            '%',
            textAlign: TextAlign.center,
            style: percentStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDigits(Color color, double fontSize) {
    final TextStyle digitStyle = AppFont.secondaryTextStyle(
      context,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.0,
    );

    return SizedBox(
      height: _percentageHeight - 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildDigitWheel(
            _tensController,
            digitStyle,
            _percentageHeight,
            _wheelWidth,
            _percentageHeight,
          ),
          _buildDigitWheel(
            _onesController,
            digitStyle,
            _percentageHeight,
            _wheelWidth,
            _percentageHeight,
          ),
        ],
      ),
    );
  }

  Widget _buildDigitWheel(
    FixedExtentScrollController controller,
    TextStyle digitStyle,
    double itemExtent,
    double wheelWidth,
    double viewportHeight,
  ) {
    return SizedBox(
      height: viewportHeight,
      width: wheelWidth,
      child: ClipRect(
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          physics: const NeverScrollableScrollPhysics(),
          itemExtent: itemExtent,
          perspective: 0.003,
          diameterRatio: 1.6,
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, index) {
              if (index < 0 || index > 9) return null;
              return Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  index.toString(),
                  textAlign: TextAlign.center,
                  style: digitStyle,
                ),
              );
            },
            childCount: 10,
          ),
        ),
      ),
    );
  }
}

class _Digits {
  final int tens;
  final int ones;
  const _Digits({required this.tens, required this.ones});
}
