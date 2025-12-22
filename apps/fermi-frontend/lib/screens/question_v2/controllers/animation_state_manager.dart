import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/widgets/answer_controller.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';
import 'package:fermi_frontend/theme/colormap.dart';
import 'package:fermi_frontend/utils/logger.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/question_state_manager.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/player_state_manager.dart';
import 'package:fermi_frontend/screens/question_v2/models/question_state.dart';

/// Manages reveal animations and animation state.
///
/// This manager is responsible for:
/// - Triggering reveal animations with correct start/end values
/// - Converting answers to display format
/// - Coordinating animation callbacks with state updates
class AnimationStateManager {
  /// Trigger reveal animation for a question
  /// This consolidates duplicate animation logic from _handleReveal and _handlePlayersAnswers
  /// Color is calculated at animation start time to ensure latest scores are used
  void triggerRevealAnimation({
    required int index,
    required AnswerValue correctAnswer,
    required QuestionStateManager stateManager,
    required PlayerStateManager playerStateManager,
    required AnswerController answerController,
    required UnitTapeController unitTapeController,
    required int currentIndex,
    required int questionCount,
    required bool isReviewMode,
    required AnswerValue? localSubmittedAnswer,
    required String myPlayerId,
    required VoidCallback onAnimationComplete,
  }) {
    AppLogger.debug(
        '_triggerRevealAnimation START: index=$index, currentIndex=$currentIndex, isReviewMode=$isReviewMode');

    if (index != currentIndex) {
      AppLogger.debug(
          '_triggerRevealAnimation ABORT: index mismatch (index=$index != currentIndex=$currentIndex)');
      return;
    }

    final state = stateManager.getQuestionState(index);
    if (state == null) {
      AppLogger.debug(
          '_triggerRevealAnimation ABORT: state is null for index=$index');
      return;
    }

    // For last question, allow animation even in review mode
    final bool shouldAnimate = !isReviewMode || index == questionCount - 1;
    if (!shouldAnimate) {
      AppLogger.debug(
          '_triggerRevealAnimation ABORT: shouldAnimate=false (isReviewMode=$isReviewMode, index=$index, questionCount=$questionCount)');
      return;
    }

    final displayAnswer = toDisplayAnswer(correctAnswer, state);

    // Use localSubmittedAnswer as ground truth for starting position
    // This is exactly what the user submitted, guaranteed accurate
    final AnswerValue startValue = localSubmittedAnswer ??
        state.userAnswer ??
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');

    AppLogger.debug(
        '_triggerRevealAnimation: startValue=$startValue, displayAnswer=$displayAnswer, correctAnswer=$correctAnswer');
    AppLogger.debug(
        '_triggerRevealAnimation: localSubmittedAnswer=$localSubmittedAnswer, state.userAnswer=${state.userAnswer}');

    stateManager.setAnimatingQuestionIndex(index);
    stateManager.updateDisplayAnswer(index, startValue);

    AppLogger.debug(
        '_triggerRevealAnimation: Set animatingQuestionIndex=$index, animationProgress[$index]=$startValue');

    // Notify will be called by parent controller

    final int indexAtStart = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.debug(
          '_triggerRevealAnimation POST-FRAME: indexAtStart=$indexAtStart, currentIndex=$currentIndex, animatingQuestionIndex=${stateManager.animatingQuestionIndex}');
      AppLogger.debug(
          '_triggerRevealAnimation POST-FRAME: isReviewMode=$isReviewMode');

      if (currentIndex == indexAtStart &&
          (stateManager.animatingQuestionIndex == indexAtStart ||
              (isReviewMode && indexAtStart == questionCount - 1)) &&
          (!isReviewMode || indexAtStart == questionCount - 1)) {
        final myScore = playerStateManager.getMyScoreForQuestion(
                indexAtStart, myPlayerId, stateManager) ??
            0;
        final Color revealColor = scoreToColor(myScore);

        AppLogger.debug(
            '_triggerRevealAnimation POST-FRAME: Calling answerController.reveal()');
        AppLogger.debug(
            '_triggerRevealAnimation POST-FRAME: startValue=$startValue, displayAnswer=$displayAnswer, duration=600ms, color=$revealColor');

        // Fade out tap and scroll indicators on unit tape
        unitTapeController.setRevealed(true, const Duration(milliseconds: 600));

        // Pass explicit start and end values
        answerController.reveal(
          startValue, // Explicit start
          displayAnswer, // Explicit end
          const Duration(milliseconds: 600),
          revealColor,
          onProgress: (progressValue) {
            AppLogger.debug(
                '_triggerRevealAnimation ON-PROGRESS: progressValue=$progressValue');
            stateManager.updateDisplayAnswer(indexAtStart, progressValue);
            onAnimationComplete(); // Notify parent to update UI
          },
          onComplete: () {
            AppLogger.debug(
                '_triggerRevealAnimation ON-COMPLETE: Animation finished for index=$indexAtStart');
            if (stateManager.animatingQuestionIndex == indexAtStart) {
              stateManager.setAnimatingQuestionIndex(null);
              stateManager.clearAnimationProgress(indexAtStart);
            }
            onAnimationComplete(); // Notify parent
          },
        );
      } else {
        AppLogger.debug(
            '_triggerRevealAnimation POST-FRAME: Conditions not met, cleaning up animation state');
        if (stateManager.animatingQuestionIndex == indexAtStart) {
          stateManager.setAnimatingQuestionIndex(null);
          stateManager.clearAnimationProgress(indexAtStart);
        }
      }
    });
  }

  /// Convert raw answer to display format (map unit ID to abbreviation)
  AnswerValue toDisplayAnswer(AnswerValue raw, QuestionState state) {
    final String idOrAbbr = raw.unit;
    // Try to get abbreviation from ID mapping
    final String abbr = state.unitIdToAbbreviation[idOrAbbr] ?? idOrAbbr;

    // If the answer already has an order of magnitude, just map the unit
    if (raw.orderOfMagnitude.isNotEmpty) {
      return AnswerValue(
        number: raw.number,
        orderOfMagnitude: raw.orderOfMagnitude,
        unit: abbr,
        rawValue: raw.rawValue,
      );
    }

    // Otherwise, decompose the absolute number into number + OM
    return AnswerValue(
      number: raw.number,
      orderOfMagnitude: raw.orderOfMagnitude,
      unit: abbr,
      rawValue: raw.rawValue,
    );
  }
}
