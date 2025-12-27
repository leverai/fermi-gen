import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/widgets/question_widget.dart';
import 'package:fermi_frontend/widgets/answer_accuracy_scale.dart';
import 'package:fermi_frontend/widgets/slider_text_mirror.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/utils/answer_format.dart';

const double kQuestionAnswerCardQuestionHeight = 24.0 * 5;
const double kQuestionAnswerCardAnswerRowHeight = 36.0;
const double kQuestionAnswerCardAccuracyScaleHeight = 48.0;
const double kQuestionAnswerCardSpacing = 24.0;
const double kQuestionAnswerCardQuestionToDividerSpacing = 0.0;

/// A reusable card widget that displays a question and answer input area.
///
/// This widget encapsulates the bordered card UI used in both party mode
/// and daily question screens. It contains:
/// - Question text with tags
/// - Horizontal divider
/// - Answer input row (SliderTextMirror + UnitTape)
/// - Answer accuracy scale
/// - Optional button widget
class QuestionAnswerCard extends StatefulWidget {
  const QuestionAnswerCard({
    super.key,
    required this.questionText,
    required this.tags,
    required this.currentAnswer,
    required this.submittedAnswer,
    required this.unitOptions,
    required this.units,
    required this.currentLocale,
    required this.onAnswerChanged,
    required this.onLocaleChanged,
    required this.editable,
    this.revealedAnswer,
    this.revealedColor,
    this.unitOptionsNotifier,
    this.unitTapeController,
    this.questionWidgetKey,
    this.unitKey,
    this.answerScaleKey,
    this.buttonWidget,
    this.allowCopy = false,
    // Other players' converted answers
    this.otherPlayersAnswers,
    this.otherPlayersAvatars,
    this.otherPlayersScores,
    this.currentPlayerAvatarUrl,
    this.currentPlayerId,
  });

  final String questionText;
  final List<String> tags;
  final AnswerValue currentAnswer;
  final AnswerValue? submittedAnswer;
  final Map<String, String> unitOptions;
  final List<String> units;
  final String currentLocale;
  final ValueChanged<AnswerValue> onAnswerChanged;
  final ValueChanged<String> onLocaleChanged;
  final bool editable;
  final AnswerValue? revealedAnswer;
  final Color? revealedColor;
  final ValueNotifier<Map<String, String>>? unitOptionsNotifier;
  final UnitTapeController? unitTapeController;
  final Key? questionWidgetKey;
  final Key? unitKey;
  final Key? answerScaleKey;
  final Widget? buttonWidget;
  final bool allowCopy;
  // Other players' converted answers
  final Map<String, AnswerValue>? otherPlayersAnswers;
  final Map<String, String?>? otherPlayersAvatars;
  final Map<String, double>? otherPlayersScores;
  final String? currentPlayerAvatarUrl;
  final String? currentPlayerId;

  @override
  State<QuestionAnswerCard> createState() => _QuestionAnswerCardState();
}

class _QuestionAnswerCardState extends State<QuestionAnswerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _carouselAnimationController;
  bool _wasRevealed = false;

  @override
  void initState() {
    super.initState();
    _carouselAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Start animation if already revealed
    if (_shouldShowCarousel()) {
      _carouselAnimationController.forward();
      _wasRevealed = true;
    }
  }

  @override
  void didUpdateWidget(QuestionAnswerCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger animation when transitioning to revealed state
    final shouldShow = _shouldShowCarousel();
    if (shouldShow && !_wasRevealed) {
      _carouselAnimationController.forward(from: 0.0);
      _wasRevealed = true;
    } else if (!shouldShow && _wasRevealed) {
      _carouselAnimationController.reset();
      _wasRevealed = false;
    }
  }

  @override
  void dispose() {
    _carouselAnimationController.dispose();
    super.dispose();
  }

  bool _shouldShowCarousel() {
    return widget.otherPlayersAnswers != null &&
        widget.otherPlayersAnswers!.isNotEmpty;
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.questionText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Format answer value for display in carousel.
  String _formatAnswerText(AnswerValue value) {
    if (value.rawValue != null) {
      final double raw = value.rawValue!;
      const double maxDisplayable = 999e12;
      if (raw < 1 || raw > maxDisplayable) {
        // Use human-readable scientific notation (e.g., "6.2 × 10³⁰")
        return formatScientificNotation(raw);
      }
    }
    return '${value.number} ${value.orderOfMagnitude}'.trim();
  }

  /// Build avatar widget for a player.
  Widget _buildAvatar(String url, AppTheme appTheme) {
    return ClipOval(
      child: Container(
        width: 12,
        height: 12,
        color: appTheme.bgLight,
        child: url.toLowerCase().endsWith('.svg')
            ? Padding(
                padding: const EdgeInsets.all(1.0),
                child: SvgPicture.network(
                  url,
                  fit: BoxFit.contain,
                  placeholderBuilder: (context) =>
                      Container(color: appTheme.bgLight),
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: appTheme.bgLight);
                },
              ),
      ),
    );
  }

  /// Build a single result chip for a player.
  Widget _buildResultChip({
    required String playerId,
    required AnswerValue answer,
    required AppTheme appTheme,
    String? avatarUrl,
    bool isCurrentPlayer = false,
    int? order,
  }) {
    return Opacity(
      opacity: isCurrentPlayer ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: appTheme.bgLight,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color:
                  isCurrentPlayer ? appTheme.secondary : appTheme.borderMuted,
              blurRadius: 0,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (order != null) ...[
              Text(
                '$order. ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: appTheme.text,
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (avatarUrl != null && avatarUrl.isNotEmpty) ...[
              _buildAvatar(avatarUrl, appTheme),
              const SizedBox(width: 4),
            ],
            Text(
              _formatAnswerText(answer),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: appTheme.text,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Data class for carousel entries (includes current player)
  List<_CarouselEntry> _getSortedCarouselEntries() {
    final List<_CarouselEntry> entries = [];

    // Add other players
    if (widget.otherPlayersAnswers != null) {
      for (final entry in widget.otherPlayersAnswers!.entries) {
        entries.add(_CarouselEntry(
          playerId: entry.key,
          answer: entry.value,
          avatarUrl: widget.otherPlayersAvatars?[entry.key],
          isCurrentPlayer: false,
          score: widget.otherPlayersScores?[entry.key] ?? 0.0,
        ));
      }
    }

    // Add current player if they have a submitted answer
    if (widget.submittedAnswer != null && widget.currentPlayerId != null) {
      entries.add(_CarouselEntry(
        playerId: widget.currentPlayerId!,
        answer: widget.submittedAnswer!,
        avatarUrl: widget.currentPlayerAvatarUrl,
        isCurrentPlayer: true,
        score: widget.otherPlayersScores?[widget.currentPlayerId!] ?? 0.0,
      ));
    }

    // Sort by score (descending - best first)
    entries.sort((a, b) => b.score.compareTo(a.score));

    return entries;
  }

  /// Build the results carousel showing all players ordered by score.
  Widget _buildResultsCarousel(BuildContext context, AppTheme appTheme) {
    final entries = _getSortedCarouselEntries();
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _carouselAnimationController,
      builder: (context, child) {
        final progress =
            Curves.easeOutBack.transform(_carouselAnimationController.value);

        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - progress)),
            child: Row(
              children: [
                Text(
                  'Leaderboard: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: appTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 30, // Increased height to accommodate shadows
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 3),
                      scrollDirection: Axis.horizontal,
                      itemCount: entries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final entry = entries[index];

                        return _buildResultChip(
                          playerId: entry.playerId,
                          answer: entry.answer,
                          appTheme: appTheme,
                          avatarUrl: entry.avatarUrl,
                          isCurrentPlayer: entry.isCurrentPlayer,
                          order: index + 1,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final showCarousel = _shouldShowCarousel();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Color.alphaBlend(
            // ignore: deprecated_member_use
            widget.revealedColor?.withOpacity(0.1) ?? Colors.transparent,
            appTheme.bg),
        borderRadius: BorderRadius.circular(appTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: widget.revealedColor ?? appTheme.shadowColor,
            offset: appTheme.shadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(appTheme.borderRadius),
        child: InkWell(
          onLongPress:
              widget.allowCopy ? () => _copyToClipboard(context) : null,
          borderRadius: BorderRadius.circular(appTheme.borderRadius),
          splashColor:
              // ignore: deprecated_member_use
              appTheme.primary.withOpacity(0.12),
          highlightColor:
              // ignore: deprecated_member_use
              appTheme.primary.withAlpha(20),
          child: Padding(
            padding: const EdgeInsets.all(kQuestionAnswerCardSpacing),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Question widget (without border, just text + tags)
                QuestionWidget(
                  key: widget.questionWidgetKey,
                  text: widget.questionText,
                  tags: widget.tags,
                  height: kQuestionAnswerCardQuestionHeight,
                  showBorder: false,
                  bottomSpacing: 24.0,
                  revealedColor: widget.revealedColor,
                ),
                const SizedBox(
                    height: kQuestionAnswerCardQuestionToDividerSpacing),
                // Horizontal separator between question and answer area
                Divider(
                  height: 1,
                  thickness: 1,
                  color: appTheme.bgDark,
                ),
                const SizedBox(height: 16),
                // Answer display row: SliderTextMirror + UnitTape (grouped together)
                SizedBox(
                  height: kQuestionAnswerCardAnswerRowHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // SliderTextMirror
                      Row(
                        children: [
                          Text(
                            'You: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              color: appTheme.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SliderTextMirror(
                            value: widget.currentAnswer,
                            unitOptions: widget.unitOptions,
                          )
                        ],
                      ),
                      // Spacing between widgets
                      if (widget.units.isNotEmpty) const SizedBox(width: 8),
                      // UnitTape (if units available)
                      if (widget.units.isNotEmpty)
                        UnitTape(
                          key: widget.unitKey,
                          units: widget.units,
                          unitOptions: widget.unitOptions,
                          initialValue: widget.currentAnswer.unit,
                          currentLocale: widget.currentLocale,
                          onUnitChanged: (unit) => widget.onAnswerChanged(
                            widget.currentAnswer.copyWith(unit: unit),
                          ),
                          onLocaleChanged: widget.onLocaleChanged,
                          editable: widget.editable,
                          unitOptionsNotifier: widget.unitOptionsNotifier,
                          controller: widget.unitTapeController,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Animated results row carousel (only when revealed with other players)
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: showCarousel
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildResultsCarousel(context, appTheme),
                            const SizedBox(height: 12),
                          ],
                        )
                      : const SizedBox(height: 28),
                ),
                // Answer Accuracy Scale (no text boxes for other players)
                AnswerAccuracyScale(
                  key: widget.answerScaleKey,
                  currentAnswer: widget.currentAnswer,
                  submittedAnswer: widget.submittedAnswer,
                  revealedAnswer: widget.revealedAnswer,
                  revealedColor: widget.revealedColor,
                  editable: widget.editable,
                  otherPlayersAnswers: widget.otherPlayersAnswers,
                  currentPlayerAvatarUrl: widget.currentPlayerAvatarUrl,
                  onAnswerChanged:
                      widget.editable ? widget.onAnswerChanged : null,
                ),
                // Button widget (if provided)
                if (widget.buttonWidget != null) ...[
                  const SizedBox(height: 48.0),
                  widget.buttonWidget!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper class for carousel entries
class _CarouselEntry {
  final String playerId;
  final AnswerValue answer;
  final String? avatarUrl;
  final bool isCurrentPlayer;
  final double score;

  _CarouselEntry({
    required this.playerId,
    required this.answer,
    this.avatarUrl,
    required this.isCurrentPlayer,
    required this.score,
  });
}
