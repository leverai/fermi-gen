import 'package:flutter/material.dart';
import 'package:fermi_frontend/widgets/animated_like_dislike.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/percentile_widget.dart';
import 'package:fermi_frontend/widgets/question_answer_card.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';

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
const double kGameCardButtonSpacing = 48.0; // Spacing between answer and button

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
    this.answerScaleKey,
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
    this.otherPlayersScores,
    this.currentPlayerAvatarUrl,
    this.currentPlayerId,
    // Answer walkthrough
    this.paragraph,
    this.walkthroughViewed = false,
    this.onWalkthroughViewed,
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
  final Key? answerScaleKey;
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
  final Map<String, double>? otherPlayersScores;
  final String? currentPlayerAvatarUrl;
  final String? currentPlayerId;

  /// JSON string of SerpAPI AI response for answer walkthrough
  final String? paragraph;

  /// Whether the walkthrough has been viewed (stops animation loop)
  final bool walkthroughViewed;

  /// Callback when the walkthrough is viewed
  final VoidCallback? onWalkthroughViewed;

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
    final bool allowCopy = showFeedback || reviewMode;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Question-Answer Card
            QuestionAnswerCard(
              questionText: questionText,
              tags: tags,
              currentAnswer: currentAnswer,
              submittedAnswer: submittedAnswer,
              unitOptions: unitOptions,
              units: units,
              currentLocale: currentLocale,
              onAnswerChanged: onAnswerChanged,
              onLocaleChanged: onLocaleChanged,
              editable: editable,
              revealedAnswer: revealedAnswer,
              revealedColor: revealedColor,
              unitOptionsNotifier: unitOptionsNotifier,
              unitTapeController: unitTapeController,
              questionWidgetKey: questionWidgetKey,
              unitKey: unitKey,
              answerScaleKey: answerScaleKey,
              buttonWidget:
                  paneState != null ? _buildMainButton(context) : null,
              allowCopy: allowCopy,
              otherPlayersAnswers: otherPlayersAnswers,
              otherPlayersAvatars: otherPlayersAvatars,
              otherPlayersScores: otherPlayersScores,
              currentPlayerAvatarUrl: currentPlayerAvatarUrl,
              currentPlayerId: currentPlayerId,
              paragraph: paragraph,
              walkthroughViewed: walkthroughViewed,
              onWalkthroughViewed: onWalkthroughViewed,
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
            top: 6,
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
