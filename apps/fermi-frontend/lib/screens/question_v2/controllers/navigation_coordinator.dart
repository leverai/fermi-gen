import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/widgets/answer_controller.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/question_state_manager.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/answer_submission_handler.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/game_timer_manager.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/player_state_manager.dart';

/// Manages carousel navigation and question index changes.
///
/// This coordinator is responsible for:
/// - Managing the PageController for carousel navigation
/// - Tracking current question index
/// - Handling index changes and syncing state
/// - Coordinating answer controller synchronization
class NavigationCoordinator {
  NavigationCoordinator({
    PageController? pageController,
  }) : _pageController = pageController ?? PageController();

  final PageController _pageController;
  int _currentIndex = 0;

  PageController get pageController => _pageController;
  int get currentIndex => _currentIndex;

  /// Handle question index change (backend-driven in live mode)
  void onQuestionIndexChanged({
    required int newIndex,
    required QuestionStateManager stateManager,
    required AnswerSubmissionHandler submissionHandler,
    required GameTimerManager timerManager,
    required AnswerController answerController,
    required bool isReviewMode,
    required VoidCallback onUpdate,
  }) {

    // Clear any ongoing animation state BEFORE changing index
    // This prevents animation callbacks from updating stale question indices
    stateManager.clearAllAnimationState();

    // Ensure state is initialized for new question BEFORE updating index
    // This ensures getDisplayAnswer() returns correct value immediately after index change
    if (!isReviewMode) {
      stateManager.ensureQuestionStateInitialized(newIndex);
    }

    // Update current index FIRST - this makes getDisplayAnswer() return correct value
    _currentIndex = newIndex;
    stateManager.setCurrentIndex(newIndex);

    // Reset submitted answer for the new question (state only, no controller sync yet)
    if (!isReviewMode) {
      submissionHandler.clearLocalSubmittedAnswer();
    }

    // Sync controller AFTER index is updated (in post-frame callback)
    // This ensures widgets are bound to correct question before controller updates
    if (!isReviewMode) {
      syncControllerToCurrentQuestion(
        stateManager: stateManager,
        answerController: answerController,
        isReviewMode: isReviewMode,
      );
    }

    // Animate carousel (fire and forget - errors are caught to allow unit testing)
    if (_pageController.hasClients) {
      _pageController
          .animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      )
          .catchError((_) {
        // Silently fail in unit tests or when widget tree is not available
        // The carousel animation is a UI concern, not critical for business logic
      });
    }

    onUpdate();
  }

  /// Sync the answer controller to the current question's state
  /// Should only be called when index is already updated to the new question
  void syncControllerToCurrentQuestion({
    required QuestionStateManager stateManager,
    required AnswerController answerController,
    required bool isReviewMode,
  }) {
    if (isReviewMode) return;

    final state = stateManager.getQuestionState(_currentIndex);
    if (state == null) return;

    // Don't sync controller if question is revealed (it should use prop-based reveal)
    if (state.isRevealed) return;

    // Get the answer to sync (userAnswer or default)
    final AnswerValue answerToSync = state.userAnswer ??
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');

    // Capture current index to verify it hasn't changed in post-frame callback
    final int indexAtCallTime = _currentIndex;

    // Sync controller in post-frame callback to ensure widget is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only sync if we're still on the same question and it's not revealed (prevent race conditions)
      if (_currentIndex == indexAtCallTime &&
          !isReviewMode &&
          !(stateManager.getQuestionState(indexAtCallTime)?.isRevealed ??
              false)) {
        answerController.jumpTo(answerToSync);
        answerController.resetVisualState();
      }
    });
  }

  /// Handle carousel page change (user swipe in review mode)
  void onCarouselPageChanged({
    required int index,
    required bool isReviewMode,
    required PlayerStateManager playerStateManager,
    required QuestionStateManager stateManager,
    required VoidCallback onUpdate,
  }) {
    if (isReviewMode && index != _currentIndex) {
      _currentIndex = index;
      stateManager.setCurrentIndex(index);

      // Clear any ongoing animation state
      stateManager.clearAllAnimationState();

      playerStateManager.updatePlayersForIndex(index, stateManager);
      onUpdate();
    }
  }
}
