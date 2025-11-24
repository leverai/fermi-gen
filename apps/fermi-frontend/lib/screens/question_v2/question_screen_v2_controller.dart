import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/widgets/answer_widget.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/player_widget_controller.dart';
import 'package:fermi_frontend/widgets/animated_like_dislike.dart';
import 'package:fermi_frontend/screens/question_v2/widgets/pane_bindings.dart';
import 'package:fermi_frontend/theme/colormap.dart';
import 'package:fermi_frontend/widgets/question_deadline_progress_tracker.dart';
import 'package:fermi_frontend/widgets/rank_widget.dart';
import 'package:fermi_frontend/utils/logger.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/game_timer_manager.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/question_state_manager.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/player_state_manager.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/animation_state_manager.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/confetti_manager.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/answer_submission_handler.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/navigation_coordinator.dart';
import 'package:fermi_frontend/screens/question_v2/models/question_state.dart';

/// Centralized controller for Question Screen V2.
/// Orchestrates game state through specialized manager classes.
/// Provides a single source of truth for the UI.
class QuestionScreenV2Controller extends ChangeNotifier {
  QuestionScreenV2Controller({
    required this.realtime,
    required this.gameId,
    required this.questionCount,
    PageController? pageController,
  }) {
    _navigationCoordinator =
        NavigationCoordinator(pageController: pageController);
    _stateManager = QuestionStateManager(currentIndex: 0);
    _playerManager = PlayerStateManager();
    _animationManager = AnimationStateManager();
    _confettiManager = ConfettiManager();
    _submissionHandler = AnswerSubmissionHandler();
    _timerManager = GameTimerManager(
      onDeadlineExpired: _handleDeadlineExpired,
      notifyListeners: notifyListeners,
    );
  }

  final GameRealtime realtime;
  final String gameId;
  final int questionCount;

  // Managers
  late final NavigationCoordinator _navigationCoordinator;
  late final QuestionStateManager _stateManager;
  late final PlayerStateManager _playerManager;
  late final AnimationStateManager _animationManager;
  late final ConfettiManager _confettiManager;
  late final AnswerSubmissionHandler _submissionHandler;
  late final GameTimerManager _timerManager;

  // Minimal state (orchestration only)
  bool _isHost = false;
  bool _isPrivate = false;
  bool _isReviewMode = false;
  bool _reviewModePending = false;
  Duration _perQuestionDuration = const Duration(seconds: 15);
  String? _errorMessage;
  String _currentLocale = 'US';

  // Answer controller (shared across questions)
  late AnswerController _answerController;

  // Unit options notifier for locale changes
  final ValueNotifier<Map<String, String>> _unitOptionsNotifier =
      ValueNotifier<Map<String, String>>({});

  // Stream subscriptions
  StreamSubscription<GameSnapshot>? _gameSub;
  final Map<int, QuestionPaneBindings> _bindingsByIndex = {};

  // Delegate getters to managers
  PageController get pageController => _navigationCoordinator.pageController;
  int get currentIndex => _navigationCoordinator.currentIndex;
  bool get isHost => _isHost;
  bool get isReviewMode => _isReviewMode;
  Duration get perQuestionDuration => _perQuestionDuration;
  String? get errorMessage => _errorMessage;
  AnswerController get answerController => _answerController;

  /// Get the answer controller for the current question
  AnswerController? get currentAnswerController {
    // Only return controller if current question is editable (not in review mode and not revealed)
    if (_isReviewMode) return null;
    final state = _stateManager.getQuestionState(currentIndex);
    if (state == null || state.isRevealed) return null;
    return _answerController;
  }

  /// Get current answer for the current question (for backward compatibility)
  AnswerValue get currentAnswer {
    final state = _stateManager.getQuestionState(currentIndex);
    return state?.userAnswer ??
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
  }

  AnswerValue? get localSubmittedAnswer =>
      _submissionHandler.localSubmittedAnswer;
  String get currentLocale => _currentLocale;
  Map<String, PlayerWidgetController> get playerControllers =>
      _playerManager.playerControllers;
  ValueNotifier<Map<String, String>> get unitOptionsNotifier =>
      _unitOptionsNotifier;
  double get autoNextProgress => _timerManager.autoNextProgress;
  QuestionDeadlineProgressTracker? get deadlineProgressTracker =>
      _timerManager.deadlineProgressTracker;
  int? get confettiRank => _confettiManager.confettiRank;
  Map<String, Rank>? get finalRanks => _confettiManager.finalRanks;

  /// Get the cached state for a question index
  QuestionState? getQuestionState(int index) {
    return _stateManager.getQuestionState(index);
  }

  /// Get the display answer for a question index
  AnswerValue getDisplayAnswer(int index) {
    return _stateManager.getDisplayAnswer(
      index,
      localSubmittedAnswer: _submissionHandler.localSubmittedAnswer,
      isReviewMode: _isReviewMode,
    );
  }

  /// Update the display answer for a question index
  void updateDisplayAnswer(int index, AnswerValue value) {
    _stateManager.updateDisplayAnswer(index, value);
    notifyListeners();
  }

  /// Get players state for a question index (for PlayersRow)
  List<PlayerState> getPlayersForIndex(int index) {
    return _playerManager.getPlayersForIndex(index, _stateManager);
  }

  void attach() {
    _answerController = AnswerController();
    _currentLocale = realtime.currentLocale?.toUpperCase() ?? 'US';
    _timerManager.init();
    _confettiManager.reset();
    _startGameWatch();
  }

  /// Handle deadline expiration - auto-submit current answer
  void _handleDeadlineExpired() {
    _submissionHandler.handleDeadlineExpired(
      currentIndex: currentIndex,
      stateManager: _stateManager,
      realtime: realtime,
      gameId: gameId,
      isReviewMode: _isReviewMode,
      onError: (msg) {
        _errorMessage = msg;
        notifyListeners();
      },
      onSuccess: () {
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  void _startGameWatch() {
    _gameSub?.cancel();
    _gameSub = realtime.watchGame(gameId).listen(
      (snapshot) {
        _isHost = snapshot.isHost;
        _isPrivate = snapshot.isPrivate;
        _perQuestionDuration = _isPrivate
            ? Duration.zero
            : Duration(
                seconds: snapshot.durationSeconds.clamp(0, 24 * 60 * 60));

        // Determine if we should be in review mode
        final bool shouldBeReviewMode =
            snapshot.state == GameState.questionLastFinished ||
                snapshot.state == GameState.gameFinished;
        final bool wasReviewMode = _isReviewMode;

        // If review mode should activate but final question is animating, delay activation
        if (shouldBeReviewMode && !wasReviewMode) {
          final bool isFinalQuestionAnimating =
              _stateManager.animatingQuestionIndex == questionCount - 1;

          if (isFinalQuestionAnimating) {
            // Delay review mode activation until final animation completes
            _reviewModePending = true;
            // Don't set _isReviewMode yet - wait for animation to complete
          } else {
            // No animation in progress, activate review mode immediately
            _isReviewMode = true;
            _reviewModePending = false;
            // Clear animation state when entering review mode
            _stateManager.clearAllAnimationState();
          }
        } else if (shouldBeReviewMode) {
          // Already in review mode or pending, ensure it's set
          if (!_isReviewMode && !_reviewModePending) {
            _isReviewMode = true;
          }
        } else {
          // Not in review mode
          _isReviewMode = false;
          _reviewModePending = false;
        }

        // Update current index from backend (only in live mode)
        if (!_isReviewMode) {
          final int newIndex =
              (snapshot.questionNumber - 1).clamp(0, questionCount - 1);
          if (newIndex != currentIndex) {
            _onQuestionIndexChanged(newIndex);
          }
        }

        // Initialize question states if needed
        _stateManager.initializeQuestionStates(questionCount);

        // Update player summaries and bind question-specific streams
        _playerManager.updatePlayers(
          snapshot: snapshot,
          stateManager: _stateManager,
          isReviewMode: _isReviewMode,
          currentIndex: currentIndex,
          questionCount: questionCount,
        );
        _bindQuestionStreams(snapshot);

        // Trigger confetti for top 3 players when game ends (same time as badges)
        // Check immediately and also defer to handle race conditions with PlayersAnswersSnapshot
        // Also check when review mode is pending (final question animating)
        if ((_isReviewMode || _reviewModePending)) {
          _confettiManager.checkAndSetConfetti(
            questionCount: questionCount,
            stateManager: _stateManager,
            myPlayerId: realtime.currentPlayerId,
            isReviewMode: _isReviewMode,
            reviewModePending: _reviewModePending,
            onUpdate: notifyListeners,
          );
          _confettiManager.scheduleConfettiCheck(
            questionCount: questionCount,
            stateManager: _stateManager,
            myPlayerId: realtime.currentPlayerId,
            isReviewMode: _isReviewMode,
            reviewModePending: _reviewModePending,
            onUpdate: notifyListeners,
          );
        }

        // Calculate final ranks for top 3 players when review mode activates
        if (_isReviewMode) {
          _confettiManager.calculateFinalRanks(
            questionCount: questionCount,
            stateManager: _stateManager,
            onUpdate: notifyListeners,
          );
        }

        notifyListeners();
      },
      onError: (Object err, StackTrace st) {
        _errorMessage = 'Connection issue. Retrying…';
        notifyListeners();
      },
    );
  }

  void _bindQuestionStreams(GameSnapshot snapshot) {
    // Bind streams for all questions that have been revealed
    for (int i = 0; i < questionCount; i++) {
      final questionUid =
          i < snapshot.questionUids.length ? snapshot.questionUids[i] : null;
      if (questionUid == null) continue;

      if (!_bindingsByIndex.containsKey(i)) {
        final bindings = QuestionPaneBindings(
          realtime: realtime,
          gameId: gameId,
          index: i,
        );

        bindings.listen(
          onReveal: (correct) => _handleReveal(i, correct),
          onPlayersAnswers: (answers) => _handlePlayersAnswers(i, answers),
          onQuestion: (question) => _handleQuestion(i, question, questionUid),
          onError: (err, st) {
            _errorMessage = 'Connection issue. Reconnecting…';
            notifyListeners();
          },
        );

        _bindingsByIndex[i] = bindings;
      }
    }
  }

  void _handleQuestion(
      int index, RevealedQuestion question, String questionUid) {
    final currentState =
        _stateManager.getQuestionState(index) ?? QuestionState();
    final voteState = question.myVoteVerdict == 1
        ? VoteState.upvoted
        : (question.myVoteVerdict == -1 ? VoteState.downvoted : VoteState.none);

    _stateManager.updateQuestionState(
      index,
      currentState.copyWith(
        questionUid: questionUid,
        questionText: question.text,
        tags: question.tags,
        units: question.units,
        unitOptions: question.unitOptions,
        unitAbbreviationToId: question.unitAbbreviationToId,
        unitIdToAbbreviation: question.unitIdToAbbreviation,
        upvotes: question.upvotes,
        voteState: voteState,
        category: question.category,
      ),
    );

    // Update unit options notifier
    _unitOptionsNotifier.value = question.unitOptions;

    // Ensure state is initialized for this question (if needed)
    // Only sync controller if this is the current question
    if (!_isReviewMode) {
      _stateManager.ensureQuestionStateInitialized(index);
      // If this is the current question, sync controller to state
      if (index == currentIndex) {
        _navigationCoordinator.syncControllerToCurrentQuestion(
          stateManager: _stateManager,
          answerController: _answerController,
          isReviewMode: _isReviewMode,
        );
      }
    }

    // Start deadline timer if this is the current question
    if (index == currentIndex &&
        !_isReviewMode &&
        _perQuestionDuration.inMilliseconds > 0) {
      _timerManager.startDeadlineTimer(_perQuestionDuration);
    }

    notifyListeners();
  }

  void _onQuestionIndexChanged(int newIndex) {
    _navigationCoordinator.onQuestionIndexChanged(
      newIndex: newIndex,
      stateManager: _stateManager,
      submissionHandler: _submissionHandler,
      timerManager: _timerManager,
      answerController: _answerController,
      isReviewMode: _isReviewMode,
      perQuestionDuration: _perQuestionDuration,
      onUpdate: notifyListeners,
    );
  }

  void _handleReveal(int index, AnswerValue correct) {
    AppLogger.debug(
        '_handleReveal: index=$index, correct=$correct, currentIndex=$currentIndex');
    final currentState =
        _stateManager.getQuestionState(index) ?? QuestionState();
    final wasRevealed = currentState.isRevealed;
    AppLogger.debug('_handleReveal: wasRevealed=$wasRevealed');
    _stateManager.updateQuestionState(
      index,
      currentState.copyWith(
        correctAnswer: correct,
        isRevealed: true,
      ),
    );

    // Stop deadline timer when revealed
    if (index == currentIndex) {
      _timerManager.stopDeadlineTimer();
    }

    // If this is the current question and it wasn't already revealed, reveal the answer widget
    // Note: _handlePlayersAnswers might have already triggered the reveal, so we check wasRevealed
    // Allow animation even if review mode activates simultaneously (for last question)
    if (index == currentIndex && !wasRevealed) {
      AppLogger.debug(
          '_handleReveal: Triggering reveal animation (index=$index, wasRevealed=$wasRevealed)');
      _triggerRevealAnimation(index, correct);
    } else {
      AppLogger.debug(
          '_handleReveal: NOT triggering animation (index=$index, currentIndex=$currentIndex, wasRevealed=$wasRevealed)');
    }

    // Start auto-next timer if not last question and not in review mode
    if (index == currentIndex && !_isReviewMode && index < questionCount - 1) {
      _startAutoNextTimer();
    }

    // Animation callback will notify listeners when animation completes
  }

  void _triggerRevealAnimation(int index, AnswerValue correctAnswer) {
    _animationManager.triggerRevealAnimation(
      index: index,
      correctAnswer: correctAnswer,
      stateManager: _stateManager,
      playerStateManager: _playerManager,
      answerController: _answerController,
      currentIndex: currentIndex,
      questionCount: questionCount,
      isReviewMode: _isReviewMode,
      reviewModePending: _reviewModePending,
      localSubmittedAnswer: _submissionHandler.localSubmittedAnswer,
      myPlayerId: realtime.currentPlayerId,
      onAnimationComplete: () {
        // Check if final question animation just completed and review mode is pending
        if (index == questionCount - 1 && _reviewModePending) {
          AppLogger.debug(
              '_triggerRevealAnimation: Scheduling review mode activation (final question)');
          _timerManager.scheduleReviewModeActivation(() {
            if (_reviewModePending) {
              _isReviewMode = true;
              _reviewModePending = false;
              // Trigger confetti check when review mode activates after animation
              _confettiManager.checkAndSetConfetti(
                questionCount: questionCount,
                stateManager: _stateManager,
                myPlayerId: realtime.currentPlayerId,
                isReviewMode: _isReviewMode,
                reviewModePending: _reviewModePending,
                onUpdate: notifyListeners,
              );
              _confettiManager.scheduleConfettiCheck(
                questionCount: questionCount,
                stateManager: _stateManager,
                myPlayerId: realtime.currentPlayerId,
                isReviewMode: _isReviewMode,
                reviewModePending: _reviewModePending,
                onUpdate: notifyListeners,
              );
              notifyListeners();
            }
          });
        }
        notifyListeners();
      },
    );
  }

  void _startAutoNextTimer() {
    _timerManager.startAutoNextTimer(
      onComplete: () {
        // Auto-trigger next if host
        if (_isHost) {
          requestNext();
        }
      },
      shouldContinue: () {
        // Check if timer should still be running
        if (_isReviewMode || _isPrivate) return false;
        if (currentIndex >= questionCount - 1) return false;

        // Verify question is still revealed
        final currentState = _stateManager.getQuestionState(currentIndex);
        if (currentState == null || !currentState.isRevealed) return false;

        return true;
      },
    );
  }

  void _handlePlayersAnswers(int index, PlayersAnswersSnapshot snapshot) {
    final currentState =
        _stateManager.getQuestionState(index) ?? QuestionState();

    // Calculate cumulative scores
    final Map<String, int> cumulativeScores = {};
    final prevCumulative = index > 0
        ? (_stateManager.getQuestionState(index - 1)?.cumulativeScores ?? {})
        : {};

    for (final entry in snapshot.scores.entries) {
      final prevScore = prevCumulative[entry.key] ?? 0;
      cumulativeScores[entry.key] = prevScore + entry.value.round();
    }

    final Map<String, int> roundScores = {
      for (final entry in snapshot.scores.entries)
        entry.key: entry.value.round()
    };

    // Convert submitted answers to display format
    final Map<String, AnswerValue> displaySubmittedAnswers = {};
    for (final entry in snapshot.submitted.entries) {
      displaySubmittedAnswers[entry.key] =
          _animationManager.toDisplayAnswer(entry.value, currentState);
    }

    // Extract correct answer from snapshot (same for all players, so take first one)
    AnswerValue? correctAnswer;
    if (snapshot.correct.isNotEmpty) {
      correctAnswer = snapshot.correct.values.first;
    }

    // Store the snapshot for later use when we have player summaries
    final wasRevealed = currentState.isRevealed;
    // Only mark as revealed if all players have answered
    final bool shouldBeRevealed =
        snapshot.allAnswered || currentState.isRevealed;
    _stateManager.updateQuestionState(
      index,
      currentState.copyWith(
        submittedAnswers: displaySubmittedAnswers,
        scores: snapshot.scores,
        cumulativeScores: cumulativeScores,
        percentiles: snapshot.percentiles,
        isRevealed: shouldBeRevealed,
        correctAnswer: correctAnswer ??
            currentState.correctAnswer, // Preserve existing if not in snapshot
      ),
    );

    // Update player controllers with scores.
    // We push both the per-question score (round) and the cumulative total so
    // that score widgets can animate immediately when the reveal snapshot arrives,
    // without waiting for the next game snapshot.
    for (final entry in snapshot.scores.entries) {
      final controller = _playerManager.playerControllers[entry.key];
      if (controller != null) {
        controller.setRoundScore(roundScores[entry.key] ?? 0);
        final int cumulativeScore =
            cumulativeScores[entry.key] ?? prevCumulative[entry.key] ?? 0;
        controller.setScore(cumulativeScore);
      }
    }

    // Trigger per-question confetti for highest scorer
    _confettiManager.triggerPerQuestionConfetti(
      index: index,
      scores: snapshot.scores,
      playerStateManager: _playerManager,
      isReviewMode: _isReviewMode,
      questionCount: questionCount,
    );

    _playerManager.applyScoresToPlayerStates(
      index: index,
      submittedAnswers: displaySubmittedAnswers,
      roundScores: roundScores,
      cumulativeScores: cumulativeScores,
      stateManager: _stateManager,
      isReviewMode: _isReviewMode,
    );

    // If animation is currently running for this question, update color with latest scores
    // This handles the case where scores arrive after animation has started
    if (_stateManager.animatingQuestionIndex == index) {
      final currentState = _stateManager.getQuestionState(index);
      if (currentState?.isRevealed == true) {
        // Trigger rebuild to update revealedColor prop (color is computed by getRevealedColor)
        notifyListeners();
      }
    }

    // If this question was just revealed and it's the current question in live mode, trigger reveal animation
    // This handles the case where the reveal stream doesn't emit or emits before the widget is ready
    // Allow animation even if review mode activates simultaneously (for last question)
    if (!wasRevealed && index == currentIndex && correctAnswer != null) {
      AppLogger.debug(
          '_handlePlayersAnswers: Triggering reveal animation (index=$index, wasRevealed=$wasRevealed, correctAnswer=$correctAnswer)');
      _triggerRevealAnimation(index, correctAnswer);
    } else {
      AppLogger.debug(
          '_handlePlayersAnswers: NOT triggering animation (index=$index, currentIndex=$currentIndex, wasRevealed=$wasRevealed, correctAnswer=$correctAnswer)');
    }

    // Start auto-next timer if this question was just revealed and it's the current question
    if (!wasRevealed &&
        index == currentIndex &&
        !_isReviewMode &&
        index < questionCount - 1) {
      _startAutoNextTimer();
    }

    // Check confetti if this is the last question and we're in review mode or pending
    // This handles the case where PlayersAnswersSnapshot arrives after GameSnapshot
    // Also handles the case where review mode is pending (final animation in progress)
    if (index == questionCount - 1 && (_isReviewMode || _reviewModePending)) {
      _confettiManager.checkAndSetConfetti(
        questionCount: questionCount,
        stateManager: _stateManager,
        myPlayerId: realtime.currentPlayerId,
        isReviewMode: _isReviewMode,
        reviewModePending: _reviewModePending,
        onUpdate: notifyListeners,
      );
      _confettiManager.scheduleConfettiCheck(
        questionCount: questionCount,
        stateManager: _stateManager,
        myPlayerId: realtime.currentPlayerId,
        isReviewMode: _isReviewMode,
        reviewModePending: _reviewModePending,
        onUpdate: notifyListeners,
      );

      // Calculate final ranks if not already calculated (handles case where scores arrive after review mode activates)
      _confettiManager.calculateFinalRanksFromScores(
        cumulativeScores: cumulativeScores,
        onUpdate: notifyListeners,
      );
    }

    // Animation callback will notify listeners when animation completes
    // Players will be updated when game snapshot arrives with player summaries
  }

  /// Handle carousel page change (user swipe in review mode)
  void onCarouselPageChanged(int index) {
    _navigationCoordinator.onCarouselPageChanged(
      index: index,
      isReviewMode: _isReviewMode,
      playerStateManager: _playerManager,
      stateManager: _stateManager,
      onUpdate: notifyListeners,
    );
  }

  /// Submit answer for current question
  Future<void> submitAnswer() async {
    await _submissionHandler.submitAnswer(
      currentIndex: currentIndex,
      stateManager: _stateManager,
      realtime: realtime,
      gameId: gameId,
      isReviewMode: _isReviewMode,
      onError: (msg) {
        _errorMessage = msg;
        notifyListeners();
      },
      onSuccess: () {
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  /// Handle answer input changes
  /// Updates the user answer directly in state for the current question
  void onAnswerChanged(AnswerValue value) {
    _stateManager.onAnswerChanged(currentIndex, value);
    notifyListeners();
  }

  /// Handle locale changes
  Future<void> onLocaleChanged(String locale) async {
    _currentLocale = locale;
    await realtime.setUserLocale(locale);
    notifyListeners();
  }

  /// Handle vote actions
  Future<void> onUpvote() async {
    final state = _stateManager.getQuestionState(currentIndex);
    if (state == null || state.questionUid == null) return;
    await realtime.upvoteQuestion(state.questionUid!);
    _stateManager.updateQuestionState(
      currentIndex,
      state.copyWith(
        upvotes: state.upvotes + 1,
        voteState: VoteState.upvoted,
      ),
    );
    notifyListeners();
  }

  Future<void> onDeUpvote() async {
    final state = _stateManager.getQuestionState(currentIndex);
    if (state == null || state.questionUid == null) return;
    await realtime.deUpvoteQuestion(state.questionUid!);
    _stateManager.updateQuestionState(
      currentIndex,
      state.copyWith(
        upvotes: (state.upvotes - 1).clamp(0, double.infinity).toInt(),
        voteState: VoteState.none,
      ),
    );
    notifyListeners();
  }

  Future<void> onDownvote() async {
    final state = _stateManager.getQuestionState(currentIndex);
    if (state == null || state.questionUid == null) return;
    await realtime.downvoteQuestion(state.questionUid!);
    _stateManager.updateQuestionState(
      currentIndex,
      state.copyWith(
        voteState: VoteState.downvoted,
      ),
    );
    notifyListeners();
  }

  Future<void> onDeDownvote() async {
    final state = _stateManager.getQuestionState(currentIndex);
    if (state == null || state.questionUid == null) return;
    await realtime.deDownvoteQuestion(state.questionUid!);
    _stateManager.updateQuestionState(
      currentIndex,
      state.copyWith(
        voteState: VoteState.none,
      ),
    );
    notifyListeners();
  }

  /// Clear confetti after it has been shown (called when animation completes).
  /// Note: Confetti state persists across carousel navigation in review mode
  /// (scrolling between questions) as it's a game-end effect, not per-question.
  void clearConfetti() {
    _confettiManager.clearConfetti(notifyListeners);
  }

  /// Request next question (host only)
  Future<void> requestNext() async {
    if (!_isHost || _isReviewMode) return;
    _timerManager.cancelAutoNextTimer();
    try {
      await realtime.goNext(gameId);
    } catch (e) {
      _errorMessage = 'Failed to request next. Please try again.';
      notifyListeners();
    }
  }

  /// Get score color for revealed answer
  Color? getRevealedColor(int index) {
    final state = _stateManager.getQuestionState(index);
    if (state == null || !state.isRevealed) return null;
    final myId = realtime.currentPlayerId;
    final score = state.scores[myId];
    return scoreToColor(score?.round() ?? 0);
  }

  /// Get display-formatted correct answer for a question index
  AnswerValue? getRevealedAnswer(int index) {
    return _stateManager.getRevealedAnswer(index);
  }

  /// Get player's percentile for a question index
  double? getMyPercentileForIndex(int index) {
    return _stateManager.getMyPercentileForIndex(
        index, realtime.currentPlayerId);
  }

  /// Get category for a question index
  String? getCategoryForIndex(int index) {
    return _stateManager.getCategoryForIndex(index);
  }

  /// Check if a question is revealed (for onboarding tutorial)
  bool isQuestionRevealed(int index) {
    return _stateManager.isQuestionRevealed(index);
  }

  @override
  void dispose() {
    _gameSub?.cancel();
    _timerManager.dispose();
    _unitOptionsNotifier.dispose();
    for (final bindings in _bindingsByIndex.values) {
      bindings.dispose();
    }
    _bindingsByIndex.clear();
    _playerManager.dispose();
    super.dispose();
  }
}
