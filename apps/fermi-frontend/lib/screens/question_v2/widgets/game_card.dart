import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fermi_frontend/widgets/question_widget.dart';
import 'package:fermi_frontend/widgets/answer_accuracy_scale.dart';
import 'package:fermi_frontend/widgets/slider_text_mirror.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';
import 'package:fermi_frontend/widgets/animated_like_dislike.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/percentile_widget.dart';

import 'package:fermi_frontend/screens/question_v2/models/question_pane_state.dart';
import 'package:fermi_frontend/widgets/circular_determinate_spinner.dart';

const double kGameCardQuestionHeight = 24.0 *
    5; // Height for three-line questions with 28px font: text (118px) + spacing (12px) + tags (21px) + bottom spacing (24px) + padding (16px)
const double kGameCardAnswerRowHeight =
    60.0; // Height for SliderTextMirror + UnitTape row
const double kGameCardSpacing = 24.0;
const double kGameCardQuestionToDividerSpacing =
    0.0; // No spacing - question widget touches divider
const double kGameCardFeedbackHeight = 48;
const double kGameCardAccuracyScaleHeight =
    48.0; // Height of AnswerAccuracyScale
const double kGameCardPadding = 48.0; // Padding top + bottom (24px * 2)
const double kGameCardMargin = 2.0; // Margin top + bottom (1px * 2)

const double kGameCardButtonHeight = 48.0;
const double kGameCardButtonSpacing = 24.0; // Spacing between answer and button

// Total height calculation:
// This constant defines the fixed height of the GameCard to ensure consistent
// layout in the carousel.
//
// Breakdown of the content height:
// - Question: 144px (24.0 * 6)
// - Answer: 59px
// - Accuracy Scale: 48px
// - Spacing (question-to-divider): 0px (question widget touches divider)
// - Spacing (divider-to-scale): 24px
// - Spacing (scale-to-answer): 24px
// - Spacing (answer-to-button): 24px
// - Button: 48px
// - Divider: 1px
// ---
// Subtotal (Card Content): 372px
//
// The card's container adds padding and a 1px margin (for the border effect),
// but these are included in the container's rendered height automatically. We do
// not add them to the manual calculation of the content's height.
//
// The feedback section below the card has a fixed height.
// - Feedback: 48px
//
// The total height is the sum of all visible components stacked vertically.
const double kGameCardTotalHeight = kGameCardQuestionHeight +
    kGameCardAnswerRowHeight +
    kGameCardAccuracyScaleHeight +
    kGameCardQuestionToDividerSpacing + // Spacing between question and divider
    (kGameCardSpacing *
        2) + // 2 SizedBox widgets (divider-to-scale, scale-to-answer)
    kGameCardButtonSpacing + // Spacing between answer and button
    kGameCardButtonHeight + // Button height
    kGameCardFeedbackHeight +
    kGameCardPadding + // Padding around content (24px top + 24px bottom)
    kGameCardMargin + // Margin around container (1px all)
    1.0; // for divider

/// A game card widget that represents a single question-answer composite.
/// Contains the question, answer input, and feedback sections.
class GameCard extends StatelessWidget {
  const GameCard({
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
    required this.revealedAnswer,
    required this.revealedColor,
    required this.editable,
    required this.showFeedback,
    required this.initialLikes,
    required this.initialVoteState,
    required this.onUpvote,
    required this.onDeUpvote,
    required this.onDownvote,
    required this.onDeDownvote,
    this.unitOptionsNotifier,
    this.unitTapeController,
    this.reviewMode = false,
    this.questionWidgetKey,
    this.likeWidgetKey,
    this.unitKey,
    // Button-related props
    this.paneState,
    this.isLast = false,
    this.isHost = false,
    this.isCurrentQuestion = false,
    this.onSubmit,
    this.onNext,
    this.autoNextProgress = 0.0,
    this.questionDeadlineProgress = 0.0,
    this.mainButtonController,
    this.submitButtonKey,
    // Percentile props
    this.percentile,
    this.showPercentile = false,
    // Other players' converted answers
    this.otherPlayersAnswers,
    this.otherPlayersAvatars,
    this.currentPlayerAvatarUrl,
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
  final AnswerValue? revealedAnswer;
  final Color? revealedColor;
  final bool editable;
  final bool showFeedback;
  final int initialLikes;
  final VoteState initialVoteState;
  final Future<void> Function()? onUpvote;
  final Future<void> Function()? onDeUpvote;
  final Future<void> Function()? onDownvote;
  final Future<void> Function()? onDeDownvote;
  final ValueNotifier<Map<String, String>>? unitOptionsNotifier;
  final UnitTapeController? unitTapeController;
  final bool reviewMode;
  final Key? questionWidgetKey;
  final Key? likeWidgetKey;
  final Key? unitKey;
  // Button-related props
  final QuestionPaneState? paneState;
  final bool isLast;
  final bool isHost;
  final bool isCurrentQuestion;
  final VoidCallback? onSubmit;
  final VoidCallback? onNext;
  final double autoNextProgress;
  final double questionDeadlineProgress;
  final MainButtonController? mainButtonController;
  final Key? submitButtonKey;
  // Percentile props
  final int? percentile;
  final bool showPercentile;
  // Other players' converted answers
  final Map<String, AnswerValue>? otherPlayersAnswers;
  final Map<String, String?>? otherPlayersAvatars;
  final String? currentPlayerAvatarUrl;

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: questionText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildMainButton(BuildContext context) {
    if (paneState == null) {
      return const SizedBox.shrink();
    }

    // Calculate colors for progress indicators
    final appTheme = Theme.of(context).extension<AppTheme>();
    final Color? calculatedAutoNextColor =
        appTheme != null && autoNextProgress > 0
            ? Color.lerp(appTheme.success, appTheme.danger, autoNextProgress)
            : null;

    switch (paneState!) {
      case QuestionPaneState.started:
        return SizedBox(
          width: double.infinity,
          child: MainButton(
            key: submitButtonKey,
            onPressed: isCurrentQuestion ? onSubmit : null,
            label: MainButtonLabel.submit,
            showSpacebarGlyph: true,
          ),
        );
      case QuestionPaneState.locked:
        return const SizedBox(
          width: double.infinity,
          child: MainButton(
            onPressed: null,
            isLoading: true,
          ),
        );
      case QuestionPaneState.finished:
        if (isLast) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: MainButton(
                  onPressed: isCurrentQuestion ? onNext : null,
                  label: MainButtonLabel.finish,
                  showSpacebarGlyph: true,
                  controller: mainButtonController,
                ),
              ),
              if (isHost &&
                  isCurrentQuestion &&
                  autoNextProgress > 0 &&
                  autoNextProgress < 1.0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CircularDeterminateSpinner(
                        progress: autoNextProgress,
                        color: calculatedAutoNextColor,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: MainButton(
                onPressed: (isHost && isCurrentQuestion) ? onNext : null,
                label: MainButtonLabel.next,
                showSpacebarGlyph: true,
                isLoading: false,
                controller: mainButtonController,
              ),
            ),
            if (isCurrentQuestion &&
                autoNextProgress > 0 &&
                autoNextProgress < 1.0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CircularDeterminateSpinner(
                      progress: autoNextProgress,
                      color: calculatedAutoNextColor,
                    ),
                  ),
                ),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final bool allowCopy = showFeedback || reviewMode;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Question-Answer Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Color.alphaBlend(
                    // ignore: deprecated_member_use
                    revealedColor?.withOpacity(0.1) ?? Colors.transparent,
                    appTheme.bgLight),
                border: Border.all(
                  color: appTheme.border,
                  width: appTheme.borderWidth,
                ),
                borderRadius: BorderRadius.circular(appTheme.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: revealedColor ?? appTheme.shadowColor,
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
                      allowCopy ? () => _copyToClipboard(context) : null,
                  borderRadius: BorderRadius.circular(appTheme.borderRadius),
                  splashColor:
                      // ignore: deprecated_member_use
                      appTheme.primary.withOpacity(0.12),
                  highlightColor:
                      // ignore: deprecated_member_use
                      appTheme.primary.withOpacity(0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(kGameCardSpacing),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Question widget (without border, just text + tags)
                        QuestionWidget(
                          key: questionWidgetKey,
                          text: questionText,
                          tags: tags,
                          height: kGameCardQuestionHeight,
                          showBorder: false,
                          bottomSpacing: 24.0,
                          revealedColor: revealedColor,
                        ),
                        const SizedBox(
                            height: kGameCardQuestionToDividerSpacing),
                        // Horizontal separator between question and answer area
                        Divider(
                          height: 1,
                          thickness: 1,
                          color:
                              // ignore: deprecated_member_use
                              appTheme.border.withOpacity(0.3),
                        ),
                        const SizedBox(height: 20),
                        // Answer display row: SliderTextMirror (left) + UnitTape (right)
                        SizedBox(
                          height: kGameCardAnswerRowHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // SliderTextMirror on the left
                              SliderTextMirror(
                                value: currentAnswer,
                              ),
                              // UnitTape on the right (if units available)
                              if (units.isNotEmpty)
                                UnitTape(
                                  key: unitKey,
                                  units: units,
                                  unitOptions: unitOptions,
                                  initialValue: currentAnswer.unit,
                                  currentLocale: currentLocale,
                                  onUnitChanged: (unit) => onAnswerChanged(
                                    currentAnswer.copyWith(unit: unit),
                                  ),
                                  onLocaleChanged: onLocaleChanged,
                                  editable: editable,
                                  unitOptionsNotifier: unitOptionsNotifier,
                                  controller: unitTapeController,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Answer Accuracy Scale
                        AnswerAccuracyScale(
                          currentAnswer: currentAnswer,
                          submittedAnswer: submittedAnswer,
                          revealedAnswer: revealedAnswer,
                          revealedColor: revealedColor,
                          editable: editable,
                          otherPlayersAnswers: otherPlayersAnswers,
                          otherPlayersAvatars: otherPlayersAvatars,
                          currentPlayerAvatarUrl: currentPlayerAvatarUrl,
                          onAnswerChanged: editable ? onAnswerChanged : null,
                        ),
                        const SizedBox(height: kGameCardButtonSpacing),
                        // Main button
                        if (paneState != null) _buildMainButton(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Feedback row (right-aligned like widget)
            // Always reserve space to prevent card from shrinking when feedback appears
            SizedBox(
              height: kGameCardFeedbackHeight,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                opacity: showFeedback ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !showFeedback,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedLikeDislike(
                          key: likeWidgetKey,
                          voteState: initialVoteState,
                          likeCount: initialLikes,
                          onUpvote: onUpvote ?? () async {},
                          onDeUpvote: onDeUpvote ?? () async {},
                          onDownvote: onDownvote ?? () async {},
                          onDeDownvote: onDeDownvote ?? () async {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Percentile widget overlay (top-right corner of card)
        if (percentile != null)
          Positioned(
            top: 8,
            right: 14,
            child: PercentileWidget(
              percentile: percentile,
              visible: showPercentile,
            ),
          ),
      ],
    );
  }
}
