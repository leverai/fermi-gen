import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:fermi_frontend/services/feedback_service.dart';
import 'package:fermi_frontend/services/pa_card_sound_service.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fermi_frontend/widgets/pa_card_confetti_overlay.dart';

enum PAChiermontTier {
  top1('GODLIKE', 'Behold, for he hath not guessed, but divined.', '🤯'),
  top5('EXQUISITE', 'You cooked with this one!', '😎'),
  top10('ACE', 'You\'re on the dean\'s list.', '😏'),
  bottom10('Source: Trust Me Bro',
      'Confidence: 100%. Accuracy: 0%. A dangerous combo.', '🤭'),
  bottom5('WRONG GALAXY',
      'You are statistically significant, but not in a good way.', '😪'),
  bottom1('Um...', 'Should we be worried about you?', '😵‍💫');

  final String title;
  final String description;
  final String emoji;

  const PAChiermontTier(this.title, this.description, this.emoji);
}

class PACard extends StatefulWidget {
  const PACard({
    super.key,
    required this.percentile,
    required this.questionText,
    required this.userAnswer,
    required this.correctAnswer,
    this.onClose,
    this.animate = false,
    this.mainButtonLabel,
    this.onMainButtonPressed,
  });

  /// The player's percentile (0.0 to 100.0).
  /// 99.0 means top 1% (best). 1.0 means bottom 1% (worst).
  final double percentile;
  final String questionText;
  final String userAnswer;
  final String correctAnswer;

  /// Callback when close button is pressed.
  final VoidCallback? onClose;

  /// If true, plays a bouncing entrance animation.
  final bool animate;

  /// Label for the main action button (e.g. "Next", "Finish").
  /// When null, no main button is shown.
  final String? mainButtonLabel;

  /// Callback when the main action button is pressed.
  final VoidCallback? onMainButtonPressed;

  /// Returns the tier for a given percentile, or null if no card should show.
  static PAChiermontTier? getTierForPercentile(double percentile) {
    if (percentile >= 99) return PAChiermontTier.top1;
    if (percentile >= 95) return PAChiermontTier.top5;
    if (percentile >= 90) return PAChiermontTier.top10;
    if (percentile <= 1) return PAChiermontTier.bottom1;
    if (percentile <= 5) return PAChiermontTier.bottom5;
    if (percentile <= 10) return PAChiermontTier.bottom10;
    return null;
  }

  @override
  State<PACard> createState() => _PACardState();
}

class _PACardState extends State<PACard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final GlobalKey _globalKey = GlobalKey();
  final PACardSoundService _soundService = PACardSoundService();
  bool _showConfetti = false;
  Color? _confettiColor;
  bool _isCapturing = false;

  Future<void> _captureAndShare() async {
    try {
      // Hide main button and wait for the layout to update before capturing.
      setState(() => _isCapturing = true);
      await Future.delayed(Duration.zero);
      await WidgetsBinding.instance.endOfFrame;

      final boundary = _globalKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isCapturing = false);
        return;
      }

      // Capture render box before async gap (for iPad share popover anchor).
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : Rect.zero;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      setState(() => _isCapturing = false);

      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath =
          await File('${directory.path}/achievement_card.png').create();
      await imagePath.writeAsBytes(pngBytes);

      FeedbackService.instance.buttonPress();
      final xFile = XFile(imagePath.path);
      await Share.shareXFiles([xFile], sharePositionOrigin: origin);
    } catch (e) {
      debugPrint('Error sharing card: $e');
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Bouncing scale animation using elasticOut curve
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    if (widget.animate) {
      _animationController.forward();
      // Play sound based on tier when animating
      _playTierSound();
      // Confetti is triggered in didChangeDependencies where context is available
    } else {
      _animationController.value = 1.0;
    }
  }

  bool _confettiTriggered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Trigger confetti once when animating (needs context for theme)
    if (widget.animate && !_confettiTriggered) {
      _confettiTriggered = true;
      final AppTheme appTheme =
          Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
      final tier = _getTier();
      if (tier != null) {
        final themeColor = _getThemeColor(appTheme, tier);
        _triggerConfettiIfTopTier(themeColor);
      }
    }
  }

  void _triggerConfettiIfTopTier(Color themeColor) {
    final tier = _getTier();
    if (tier == null) return;
    // Only show confetti for top tiers (top1, top5, top10)
    if (tier == PAChiermontTier.top1 ||
        tier == PAChiermontTier.top5 ||
        tier == PAChiermontTier.top10) {
      setState(() {
        _showConfetti = true;
        _confettiColor = themeColor;
      });
    }
  }

  void _playTierSound() async {
    final tier = _getTier();
    if (tier == null) return;

    await _soundService.initialize();

    switch (tier) {
      case PAChiermontTier.top1:
        await _soundService.playTop1();
        break;
      case PAChiermontTier.top5:
      case PAChiermontTier.top10:
        await _soundService.playTop();
        break;
      case PAChiermontTier.bottom1:
      case PAChiermontTier.bottom5:
      case PAChiermontTier.bottom10:
        await _soundService.playBottom();
        break;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _soundService.dispose();
    super.dispose();
  }

  PAChiermontTier? _getTier() {
    return PACard.getTierForPercentile(widget.percentile);
  }

  Color _getThemeColor(AppTheme theme, PAChiermontTier tier) {
    final hsl = HSLColor.fromColor(theme.success);
    final nextHue = (hsl.hue + ((tier.index - 1) * 53)) % 360;
    return hsl.withHue(nextHue).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final tier = _getTier();

    if (tier == null) {
      return const SizedBox.shrink();
    }

    final themeColor = _getThemeColor(appTheme, tier);

    Widget card = RepaintBoundary(
      key: _globalKey,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: appTheme.bgLight,
          borderRadius: BorderRadius.circular(appTheme.borderRadius),
          boxShadow: [
            BoxShadow(
              color: appTheme.shadowColor,
              offset: appTheme.shadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Section (A + B)
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: 32,
                        left: 16,
                        right: 16,
                        bottom: 32,
                      ),
                      decoration: BoxDecoration(
                        color: themeColor.withAlpha(40),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(appTheme.borderRadius - 1),
                          topRight: Radius.circular(appTheme.borderRadius - 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(tier.emoji,
                              style: const TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            tier.title.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: themeColor,
                              height: 1.1,
                            ).copyWith(letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.percentile > 50
                                ? 'Top ${100 - widget.percentile.round()}%'
                                : 'Bottom ${widget.percentile.round()}%',
                            textAlign: TextAlign.center,
                            style: AppFont.secondaryTextStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '"${tier.description}"',
                            textAlign: TextAlign.center,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 14,
                              color: appTheme.textMuted,
                              fontWeight: FontWeight.w400,
                            ).copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    // Share button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: _captureAndShare,
                        child: Container(
                          width: 32,
                          height: 32,
                          color: Colors.transparent,
                          child: Center(
                            child: Icon(
                              Icons.share,
                              size: 20,
                              color: themeColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Close button
                    if (widget.onClose != null)
                      Positioned(
                        top: 8,
                        left: 12,
                        child: GestureDetector(
                          onTap: () {
                            FeedbackService.instance.buttonPress();
                            widget.onClose?.call();
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            color: Colors.transparent,
                            child: Center(
                              child: Text(
                                '×',
                                style: AppFont.primaryTextStyle(
                                  context,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w400,
                                  color: themeColor,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                Divider(color: appTheme.bgDark, height: 1),

                // Bottom Section (C)
                Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, top: 20, bottom: 30),
                  child: Table(
                    columnWidths: const {
                      0: IntrinsicColumnWidth(),
                      1: FlexColumnWidth(),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.top,
                    children: [
                      TableRow(
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(right: 16, bottom: 12),
                            child: Text(
                              'The Question:',
                              style: AppFont.primaryTextStyle(
                                context,
                                fontSize: 12,
                                color: appTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              widget.questionText,
                              style: AppFont.primaryTextStyle(
                                context,
                                fontSize: 14,
                                color: appTheme.text,
                              ).copyWith(fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(right: 16, bottom: 8),
                            child: Text(
                              'You Said:',
                              style: AppFont.primaryTextStyle(
                                context,
                                fontSize: 12,
                                color: appTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              widget.userAnswer,
                              style: AppFont.secondaryTextStyle(
                                context,
                                fontSize: 16,
                                color: appTheme.text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              'Answer:',
                              style: AppFont.primaryTextStyle(
                                context,
                                fontSize: 12,
                                color: appTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            widget.correctAnswer,
                            style: AppFont.secondaryTextStyle(
                              context,
                              fontSize: 16,
                              color: appTheme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Main action button (e.g. Next / Finish)
                if (!_isCapturing &&
                    widget.mainButtonLabel != null &&
                    widget.onMainButtonPressed != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: MainButton(
                        onPressed: () {
                          FeedbackService.instance.buttonPress();
                          widget.onMainButtonPressed?.call();
                        },
                        customLabel: widget.mainButtonLabel,
                      ),
                    ),
                  ),
              ],
            ),
            // Watermark
            Positioned(
              bottom: 4,
              right: 12,
              child: Opacity(
                  opacity: 0.4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/icon-fg.png',
                        height: 20,
                        width: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Guesstimate: Not Trivia!',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 10,
                          color: appTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )),
            ),
          ],
        ),
      ),
    );

    // Wrap in Stack with confetti overlay if showing
    Widget result = card;
    if (_showConfetti && _confettiColor != null) {
      result = Stack(
        children: [
          card,
          Positioned.fill(
            child: IgnorePointer(
              child: PACardConfettiOverlay(
                themeColor: _confettiColor!,
                onComplete: () {
                  if (mounted) setState(() => _showConfetti = false);
                },
              ),
            ),
          ),
        ],
      );
    }

    // Apply bounce animation if enabled
    if (widget.animate) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: result,
      );
    }

    return result;
  }
}
