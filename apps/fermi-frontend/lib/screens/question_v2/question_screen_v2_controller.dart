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

/// Cached state for a single question
class QuestionState {
  final String? questionUid;
  final String questionText;
  final List<String> tags;
  final List<String> units;
  final Map<String, String> unitOptions;
  final Map<String, String> unitAbbreviationToId;
  final Map<String, String> unitIdToAbbreviation;
  final int upvotes;
  final VoteState voteState;
  final String category;
  final AnswerValue? correctAnswer;
  final AnswerValue? userAnswer; // Current user input for this question
  final Map<String, AnswerValue> submittedAnswers; // playerId -> answer
  final Map<String, double> scores; // playerId -> score
  final Map<String, int>
      cumulativeScores; // playerId -> cumulative score up to this question
  final Map<String, double> percentiles; // playerId -> percentile (0.0-1.0)
  final List<PlayerState> players; // Sorted by rank
  final bool isRevealed;
  final Duration? duration;

  QuestionState({
    this.questionUid,
    this.questionText = '',
    this.tags = const [],
    this.units = const [],
    this.unitOptions = const {},
    this.unitAbbreviationToId = const {},
    this.unitIdToAbbreviation = const {},
    this.upvotes = 0,
    this.voteState = VoteState.none,
    this.category = '',
    this.correctAnswer,
    this.userAnswer,
    this.submittedAnswers = const {},
    this.scores = const {},
    this.cumulativeScores = const {},
    this.percentiles = const {},
    this.players = const [],
    this.isRevealed = false,
    this.duration,
  });

  QuestionState copyWith({
    String? questionUid,
    String? questionText,
    List<String>? tags,
    List<String>? units,
    Map<String, String>? unitOptions,
    Map<String, String>? unitAbbreviationToId,
    Map<String, String>? unitIdToAbbreviation,
    int? upvotes,
    VoteState? voteState,
    String? category,
    AnswerValue? correctAnswer,
    AnswerValue? userAnswer,
    Map<String, AnswerValue>? submittedAnswers,
    Map<String, double>? scores,
    Map<String, int>? cumulativeScores,
    Map<String, double>? percentiles,
    List<PlayerState>? players,
    bool? isRevealed,
    Duration? duration,
  }) {
    return QuestionState(
      questionUid: questionUid ?? this.questionUid,
      questionText: questionText ?? this.questionText,
      tags: tags ?? this.tags,
      units: units ?? this.units,
      unitOptions: unitOptions ?? this.unitOptions,
      unitAbbreviationToId: unitAbbreviationToId ?? this.unitAbbreviationToId,
      unitIdToAbbreviation: unitIdToAbbreviation ?? this.unitIdToAbbreviation,
      upvotes: upvotes ?? this.upvotes,
      voteState: voteState ?? this.voteState,
      category: category ?? this.category,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      userAnswer: userAnswer ?? this.userAnswer,
      submittedAnswers: submittedAnswers ?? this.submittedAnswers,
      scores: scores ?? this.scores,
      cumulativeScores: cumulativeScores ?? this.cumulativeScores,
      percentiles: percentiles ?? this.percentiles,
      players: players ?? this.players,
      isRevealed: isRevealed ?? this.isRevealed,
      duration: duration ?? this.duration,
    );
  }
}

/// Centralized controller for Question Screen V2.
/// Manages all game state, caches historical data for review mode,
/// and provides a single source of truth for the UI.
class QuestionScreenV2Controller extends ChangeNotifier {
  QuestionScreenV2Controller({
    required this.realtime,
    required this.gameId,
    required this.questionCount,
    PageController? pageController,
  }) : _pageController = pageController ?? PageController();

  final GameRealtime realtime;
  final String gameId;
  final int questionCount;
  final PageController _pageController;

  // Current state
  int _currentIndex = 0;
  bool _isHost = false;
  bool _isPrivate = false;
  bool _isReviewMode = false;
  bool _reviewModePending =
      false; // Review mode is pending until final animation completes
  Duration _perQuestionDuration = const Duration(seconds: 15);
  String? _errorMessage;

  // Historical state cache: index -> QuestionState
  final Map<int, QuestionState> _questionStates = {};

  // Animation progress tracking (ONLY used during active reveal animations)
  int? _animatingQuestionIndex;
  final Map<int, AnswerValue> _animationProgress = {};

  // Local submitted answer tracking (for current question only)
  AnswerValue? _localSubmittedAnswer;
  late AnswerController _answerController;

  // Player controllers: playerId -> controller
  final Map<String, PlayerWidgetController> _playerControllers = {};
  Map<String, PlayerSummary> _latestPlayerSummaries = {};
  List<String> _latestPlayerOrder = const [];

  // Stream subscriptions
  StreamSubscription<GameSnapshot>? _gameSub;
  final Map<int, QuestionPaneBindings> _bindingsByIndex = {};

  // Current locale
  String _currentLocale = 'US';

  // Unit options notifier for locale changes
  final ValueNotifier<Map<String, String>> _unitOptionsNotifier =
      ValueNotifier<Map<String, String>>({});

  // Auto-next timer state
  Timer? _autoNextTimer;
  DateTime? _autoNextStartedAt;
  double _autoNextProgress = 0.0;
  static const Duration _autoNextDuration = Duration(seconds: 10);

  // Review mode activation timer (delays activation after final animation)
  Timer? _reviewModeActivationTimer;

  // Deadline progress tracker
  QuestionDeadlineProgressTracker? _deadlineProgressTracker;

  // Confetti state
  int?
      _confettiRank; // tracks rank (1, 2, or 3) for game-end confetti. Persists across carousel navigation in review mode.
  Map<String, Rank>?
      _finalRanks; // Final ranks for top 3 players, calculated once when review mode activates
  bool _confettiShown = false; // prevents duplicate confetti triggers

  PageController get pageController => _pageController;
  int get currentIndex => _currentIndex;
  bool get isHost => _isHost;
  bool get isReviewMode => _isReviewMode;
  Duration get perQuestionDuration => _perQuestionDuration;
  String? get errorMessage => _errorMessage;
  AnswerController get answerController => _answerController;

  /// Get the answer controller for the current question
  AnswerController? get currentAnswerController {
    // Only return controller if current question is editable (not in review mode and not revealed)
    if (_isReviewMode) return null;
    final state = _questionStates[_currentIndex];
    if (state == null || state.isRevealed) return null;
    return _answerController;
  }

  /// Get current answer for the current question (for backward compatibility)
  AnswerValue get currentAnswer {
    final state = _questionStates[_currentIndex];
    return state?.userAnswer ??
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
  }

  AnswerValue? get localSubmittedAnswer => _localSubmittedAnswer;
  String get currentLocale => _currentLocale;
  Map<String, PlayerWidgetController> get playerControllers =>
      _playerControllers;
  ValueNotifier<Map<String, String>> get unitOptionsNotifier =>
      _unitOptionsNotifier;
  double get autoNextProgress => _autoNextProgress;
  QuestionDeadlineProgressTracker? get deadlineProgressTracker =>
      _deadlineProgressTracker;
  int? get confettiRank => _confettiRank;
  Map<String, Rank>? get finalRanks => _finalRanks;

  /// Get the cached state for a question index
  QuestionState? getQuestionState(int index) {
    return _questionStates[index];
  }

  /// Get the display answer for a question index
  /// This is a pure function that computes the display value from state
  /// Priority: animation progress > revealed answer > user answer > default
  /// Ensures state is initialized for current question if needed
  AnswerValue getDisplayAnswer(int index) {
    final state = _questionStates[index];
    final bool isCurrentQuestion = index == _currentIndex;
    final bool showFeedback = state?.isRevealed ?? false;

    // Priority 1: Animation progress (if question is actively animating OR scheduled to animate)
    if (_animatingQuestionIndex == index) {
      if (_animationProgress.containsKey(index)) {
        // Animation in progress - return current animation progress
        final progress = _animationProgress[index]!;
        AppLogger.debug(
            'getDisplayAnswer[$index]: Priority 1 (animation progress) -> $progress');
        return progress;
      }
      // Animation scheduled but not started yet - return submitted answer as starting point
      // Use _localSubmittedAnswer if available (for current question), otherwise fall back to state.userAnswer
      if (state != null && isCurrentQuestion) {
        final start = _localSubmittedAnswer ??
            state.userAnswer ??
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
        AppLogger.debug(
            'getDisplayAnswer[$index]: Priority 1 (scheduled, current) -> $start');
        return start;
      }
      if (state != null) {
        final start = state.userAnswer ??
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
        AppLogger.debug(
            'getDisplayAnswer[$index]: Priority 1 (scheduled, non-current) -> $start');
        return start;
      }
    }

    // Priority 2: Revealed answer (for revealed questions, ONLY if not animating)
    if (showFeedback && state != null && _animatingQuestionIndex != index) {
      final revealed = getRevealedAnswer(index);
      if (revealed != null) {
        AppLogger.debug(
            'getDisplayAnswer[$index]: Priority 2 (revealed) -> $revealed');
        return revealed;
      }
    }

    // Priority 3: User's current input (for current editable question in live mode)
    if (isCurrentQuestion && !_isReviewMode && !showFeedback) {
      // Ensure state exists and is initialized
      if (state == null) {
        // State doesn't exist yet - return default
        AppLogger.debug(
            'getDisplayAnswer[$index]: Priority 3 (default, state null)');
        return const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
      }

      // If userAnswer is null or has empty unit but units are available, initialize it now
      // This handles lazy initialization when getDisplayAnswer is called before _ensureQuestionStateInitialized
      if (state.userAnswer == null ||
          (state.userAnswer != null &&
              state.userAnswer!.unit.isEmpty &&
              state.units.isNotEmpty)) {
        AnswerValue defaultAnswer =
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
        if (state.units.isNotEmpty) {
          defaultAnswer = AnswerValue(
            number: defaultAnswer.number,
            orderOfMagnitude: defaultAnswer.orderOfMagnitude,
            unit: state.units.first,
          );
        }
        // Initialize userAnswer immediately to prevent stale values
        _questionStates[index] = state.copyWith(userAnswer: defaultAnswer);
        AppLogger.debug(
            'getDisplayAnswer[$index]: Priority 3 (initialized) -> $defaultAnswer');
        return defaultAnswer;
      }

      AppLogger.debug(
          'getDisplayAnswer[$index]: Priority 3 (user answer) -> ${state.userAnswer}');
      return state.userAnswer!;
    }

    // Priority 4: Default fallback for non-current or uninitialized questions
    AppLogger.debug('getDisplayAnswer[$index]: Priority 4 (default fallback)');
    return const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
  }

  /// Update the display answer for a question index
  /// This should be called during animations to keep display value in sync
  void updateDisplayAnswer(int index, AnswerValue value) {
    // Only update if this question is actively animating
    if (_animatingQuestionIndex == index) {
      _animationProgress[index] = value;
      notifyListeners();
    }
    // Silently ignore updates for non-animating questions (prevents stale values)
  }

  /// Get players state for a question index (for PlayersRow)
  List<PlayerState> getPlayersForIndex(int index) {
    final state = _questionStates[index];
    if (state != null && state.players.isNotEmpty) {
      return state.players;
    }
    // Fallback: return empty list or initial players
    return const [];
  }

  void attach() {
    _answerController = AnswerController();
    _currentLocale = realtime.currentLocale?.toUpperCase() ?? 'US';
    _deadlineProgressTracker = QuestionDeadlineProgressTracker();
    _deadlineProgressTracker?.setOnExpired(_handleDeadlineExpired);
    _confettiRank = null;
    _confettiShown = false;
    _startGameWatch();
  }

  /// Handle deadline expiration - auto-submit current answer
  void _handleDeadlineExpired() {
    if (_isReviewMode) return;
    if (_localSubmittedAnswer != null) return; // Already submitted

    final state = _questionStates[_currentIndex];
    if (state == null) return;

    // Get user answer from state, or use default
    final AnswerValue currentAnswer = state.userAnswer ??
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');

    // Apply fallbacks: ensure unit is set if available, number is at least 1
    final AnswerValue withFallbacks = _withFallbacks(currentAnswer, state);

    // Check if unit mapping is needed
    final bool needsUnitMap = withFallbacks.unit.isNotEmpty &&
        (state.unitAbbreviationToId[withFallbacks.unit] == null ||
            state.unitAbbreviationToId[withFallbacks.unit]!.isEmpty);

    if (needsUnitMap && state.units.isNotEmpty) {
      // Unit map not ready yet - try to trigger locale update and queue submission
      // For now, submit with fallback unit (first available unit)
      final AnswerValue fallbackAnswer = AnswerValue(
        number: withFallbacks.number,
        orderOfMagnitude: withFallbacks.orderOfMagnitude,
        unit: state.units.first,
      );
      _submitAnswerValue(fallbackAnswer, state);
    } else {
      // Unit map is ready or no unit needed - submit directly
      _submitAnswerValue(withFallbacks, state);
    }
  }

  /// Apply fallbacks to answer value (ensure unit is set if available, number >= 1)
  AnswerValue _withFallbacks(AnswerValue value, QuestionState state) {
    final String resolvedUnit = value.unit.isEmpty && state.units.isNotEmpty
        ? state.units.first
        : value.unit;
    final int resolvedNumber = value.number > 0 ? value.number : 1;

    return AnswerValue(
      number: resolvedNumber,
      orderOfMagnitude: value.orderOfMagnitude,
      unit: resolvedUnit,
    );
  }

  /// Submit an answer value (internal helper)
  Future<void> _submitAnswerValue(
      AnswerValue answerValue, QuestionState state) async {
    _localSubmittedAnswer = answerValue;

    // Convert UI answer to submission format
    final AnswerValue toSubmit = _convertForSubmission(answerValue, state);

    try {
      await realtime.submitAnswer(gameId, _currentIndex, toSubmit);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Auto-submit failed. Please check your connection.';
      _localSubmittedAnswer = null; // Reset on error
      notifyListeners();
    }
  }

  void _startGameWatch() {
    _gameSub?.cancel();
    _gameSub = realtime.watchGame(gameId).listen(
      (snapshot) {
        _isHost = snapshot.isHost;
        _isPrivate = snapshot.isPrivate;
        _perQuestionDuration = _isPrivate
            ? Duration.zero
            : Duration(seconds: snapshot.durationSeconds.clamp(0, 24 * 60 * 60));

        // Determine if we should be in review mode
        final bool shouldBeReviewMode =
            snapshot.state == GameState.questionLastFinished ||
                snapshot.state == GameState.gameFinished;
        final bool wasReviewMode = _isReviewMode;

        // If review mode should activate but final question is animating, delay activation
        if (shouldBeReviewMode && !wasReviewMode) {
          final bool isFinalQuestionAnimating =
              _animatingQuestionIndex == questionCount - 1;

          if (isFinalQuestionAnimating) {
            // Delay review mode activation until final animation completes
            _reviewModePending = true;
            // Don't set _isReviewMode yet - wait for animation to complete
          } else {
            // No animation in progress, activate review mode immediately
            _isReviewMode = true;
            _reviewModePending = false;
            // Clear animation state when entering review mode
            _animatingQuestionIndex = null;
            _animationProgress.clear();
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
          if (newIndex != _currentIndex) {
            _onQuestionIndexChanged(newIndex);
          }
        }

        // Initialize question states if needed
        for (int i = 0; i < questionCount; i++) {
          if (!_questionStates.containsKey(i)) {
            _questionStates[i] = QuestionState();
          }
        }

        // Update player summaries and bind question-specific streams
        _updatePlayers(snapshot);
        _bindQuestionStreams(snapshot);

        // Trigger confetti for top 3 players when game ends (same time as badges)
        // Check immediately and also defer to handle race conditions with PlayersAnswersSnapshot
        // Also check when review mode is pending (final question animating)
        if ((_isReviewMode || _reviewModePending) && !_confettiShown) {
          _checkAndSetConfetti(); // Try immediately
          _scheduleConfettiCheck(); // Also try on next frame
        }

        // Calculate final ranks for top 3 players when review mode activates
        // This ensures rank icons remain static during reordering in review mode
        // Use cumulativeScores directly (source of truth) rather than players list
        if (_isReviewMode && _finalRanks == null) {
          final lastQuestionState = _questionStates[questionCount - 1];
          if (lastQuestionState != null &&
              lastQuestionState.cumulativeScores.isNotEmpty) {
            // Sort players by final cumulative score (descending) to get top 3
            final List<MapEntry<String, int>> sortedScores =
                lastQuestionState.cumulativeScores.entries.toList()
                  ..sort((a, b) {
                    if (a.value != b.value) {
                      return b.value.compareTo(a.value); // Descending order
                    }
                    // Tiebreaker: use playerId for stable sort
                    return a.key.compareTo(b.key);
                  });
            // Take top 3 and map their playerId to Rank enum
            _finalRanks = <String, Rank>{};
            for (int i = 0; i < sortedScores.length && i < 3; i++) {
              final entry = sortedScores[i];
              final String playerId = entry.key;
              switch (i) {
                case 0:
                  _finalRanks![playerId] = Rank.first;
                  break;
                case 1:
                  _finalRanks![playerId] = Rank.second;
                  break;
                case 2:
                  _finalRanks![playerId] = Rank.third;
                  break;
              }
            }
          }
        }

        notifyListeners();
      },
      onError: (Object err, StackTrace st) {
        _errorMessage = 'Connection issue. Retrying…';
        notifyListeners();
      },
    );
  }

  /// Schedule confetti check on next frame to avoid race conditions
  void _scheduleConfettiCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSetConfetti();
    });
  }

  /// Check if confetti should be shown for the current player
  /// Works in both review mode and pending review mode (when final animation is in progress)
  void _checkAndSetConfetti() {
    if (_confettiShown) return;
    // Allow check when review mode is active OR when review mode is pending (final question animating)
    if (!_isReviewMode && !_reviewModePending) return;

    final String myId = realtime.currentPlayerId;
    if (myId.isEmpty) return;

    // Get cumulative scores from the last question's state
    final lastQuestionState = _questionStates[questionCount - 1];
    if (lastQuestionState == null ||
        lastQuestionState.cumulativeScores.isEmpty) {
      return; // Not ready yet, will try again later
    }

    // Sort players by cumulative score (descending) to determine ranking
    final List<MapEntry<String, int>> sortedScores =
        lastQuestionState.cumulativeScores.entries.toList()
          ..sort((a, b) {
            if (a.value != b.value) {
              return b.value.compareTo(a.value); // Descending order
            }
            // Tiebreaker: use playerId for stable sort
            return a.key.compareTo(b.key);
          });

    // Find current player's rank (0-based index in sorted list)
    final int myIndex = sortedScores.indexWhere((entry) => entry.key == myId);
    if (myIndex >= 0 && myIndex < 3) {
      final int myRank = myIndex + 1; // Convert 0-based index to 1-based rank
      _confettiRank = myRank;
      _confettiShown = true;
      notifyListeners();
    }
  }

  void _updatePlayers(GameSnapshot snapshot) {
    // Extract active players and sort by rank
    final List<MapEntry<String, PlayerSummary>> entries = snapshot
        .players.entries
        .where((e) => e.value.isActive)
        .toList(growable: false);
    entries.sort((a, b) {
      final int ar = a.value.rank ?? 0;
      final int br = b.value.rank ?? 0;
      return ar.compareTo(br);
    });

    _latestPlayerSummaries = {
      for (final entry in entries) entry.key: entry.value
    };
    _latestPlayerOrder =
        entries.map((entry) => entry.key).toList(growable: false);

    // Update player controllers
    final Set<String> currentPlayerIds = entries.map((e) => e.key).toSet();
    for (final pid in currentPlayerIds) {
      if (!_playerControllers.containsKey(pid)) {
        _playerControllers[pid] = PlayerWidgetController();
      }
    }
    // Remove controllers for players that left
    final toRemove = _playerControllers.keys
        .where((pid) => !currentPlayerIds.contains(pid))
        .toList();
    for (final pid in toRemove) {
      _playerControllers[pid]?.dispose();
      _playerControllers.remove(pid);
    }

    // Track which players have submitted answers
    final Map<String, bool> hasAnsweredByPlayerId = snapshot.progressAnswered;

    // TODO(maintainers): This block mirrors `_applyScoresToPlayerStates`. Keep both
    // in sync until we explicitly refactor the player mapping pipeline. Please do
    // not attempt that cleanup unless product/design asks for it; the current flow
    // relies on these live-mode fallbacks.
    // Update player states for current question (live mode) or all revealed questions (review mode)
    final int targetIndex = _isReviewMode ? _currentIndex : _currentIndex;
    final state = _questionStates[targetIndex];

    if (state != null) {
      // Get previous question's cumulative scores as fallback for score continuity
      final Map<String, int> prevCumulativeScores = {};
      if (!_isReviewMode && targetIndex > 0) {
        final prevState = _questionStates[targetIndex - 1];
        if (prevState != null) {
          prevCumulativeScores.addAll(prevState.cumulativeScores);
        }
      }

      // Build player states from snapshot and cached scores
      final List<PlayerState> players = [];
      for (final entry in entries) {
        final pid = entry.key;
        final summary = entry.value;
        // Use cumulative score from current question, or fallback to previous question's cumulative score
        final cumulativeScore =
            state.cumulativeScores[pid] ?? prevCumulativeScores[pid] ?? 0;
        final roundScore = state.scores[pid]?.round() ?? 0;
        final submittedAnswer = state.submittedAnswers[pid];
        final hasAnswered = hasAnsweredByPlayerId[pid] ?? false;

        // Determine ring state
        RingState ringState;
        if (_isReviewMode || state.isRevealed) {
          ringState = RingState.review;
        } else if (hasAnswered) {
          ringState = RingState.completed;
        } else {
          ringState = RingState.countdown;
        }

        // Determine status
        PlayerStatus status;
        if (submittedAnswer != null) {
          status = PlayerStatus.answer;
        } else if (hasAnswered) {
          status = PlayerStatus.ready;
        } else if (!state.isRevealed) {
          status = PlayerStatus.waiting;
        } else {
          status = PlayerStatus.ready;
        }

        players.add(PlayerState(
          playerId: pid,
          displayName: summary.name,
          avatarUrl: summary.pictureUrl,
          isHost: summary.isHost,
          score: cumulativeScore,
          roundScore: roundScore,
          submittedAnswer: submittedAnswer,
          status: status,
          ringState: ringState,
        ));

        // Update player controller scores
        // Note: setScore will animate, but it's necessary to maintain continuity
        // The score continuity is ensured by using previous question's cumulative scores as fallback
        final controller = _playerControllers[pid];
        if (controller != null) {
          controller.setScore(cumulativeScore);
          controller.setRoundScore(roundScore);
        }
      }

      _questionStates[targetIndex] = state.copyWith(players: players);
    }

    // Also update all revealed questions in review mode
    if (_isReviewMode) {
      for (int i = 0; i < questionCount; i++) {
        if (i == targetIndex) continue; // Already updated above
        final state = _questionStates[i];
        if (state == null || !state.isRevealed) continue;

        final List<PlayerState> players = [];
        for (final entry in entries) {
          final pid = entry.key;
          final summary = entry.value;
          final cumulativeScore = state.cumulativeScores[pid] ?? 0;
          final roundScore = state.scores[pid]?.round() ?? 0;
          final submittedAnswer = state.submittedAnswers[pid];

          players.add(PlayerState(
            playerId: pid,
            displayName: summary.name,
            avatarUrl: summary.pictureUrl,
            isHost: summary.isHost,
            score: cumulativeScore,
            roundScore: roundScore,
            submittedAnswer: submittedAnswer,
            status: submittedAnswer != null
                ? PlayerStatus.answer
                : PlayerStatus.ready,
            ringState: RingState.review,
          ));
        }

        _questionStates[i] = state.copyWith(players: players);
      }
    }
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
    final currentState = _questionStates[index] ?? QuestionState();
    final voteState = question.myVoteVerdict == 1
        ? VoteState.upvoted
        : (question.myVoteVerdict == -1 ? VoteState.downvoted : VoteState.none);

    _questionStates[index] = currentState.copyWith(
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
    );

    // Update unit options notifier
    _unitOptionsNotifier.value = question.unitOptions;

    // Ensure state is initialized for this question (if needed)
    // Only sync controller if this is the current question
    if (!_isReviewMode) {
      _ensureQuestionStateInitialized(index);
      // If this is the current question, sync controller to state
      if (index == _currentIndex) {
        _syncControllerToCurrentQuestion();
      }
    }

    // Start deadline timer if this is the current question
    if (index == _currentIndex &&
        !_isReviewMode &&
        _perQuestionDuration.inMilliseconds > 0) {
      _deadlineProgressTracker?.start(_perQuestionDuration,
          onExpired: _handleDeadlineExpired);
    }

    notifyListeners();
  }

  /// Ensure question state exists and has a userAnswer initialized (if needed)
  /// This only initializes state, does NOT sync controller
  /// Only initializes when units are available to ensure correct default unit
  void _ensureQuestionStateInitialized(int index) {
    final state = _questionStates[index];
    if (state == null) return;

    // Only initialize if userAnswer is null OR if userAnswer exists but has empty unit
    // and units are now available (handles case where question data arrives after navigation)
    final bool shouldInitialize = state.userAnswer == null ||
        (state.userAnswer != null &&
            state.userAnswer!.unit.isEmpty &&
            state.units.isNotEmpty);

    if (shouldInitialize) {
      AnswerValue defaultAnswer =
          const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');

      // If units are available, set first unit as default
      if (state.units.isNotEmpty) {
        defaultAnswer = AnswerValue(
          number: defaultAnswer.number,
          orderOfMagnitude: defaultAnswer.orderOfMagnitude,
          unit: state.units.first,
        );
      }

      // Update state with default answer (state only, no controller sync)
      _questionStates[index] = state.copyWith(userAnswer: defaultAnswer);
    }
  }

  /// Sync the answer controller to the current question's state
  /// Should only be called when index is already updated to the new question
  void _syncControllerToCurrentQuestion() {
    if (_isReviewMode) return;

    final state = _questionStates[_currentIndex];
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
          !_isReviewMode &&
          !(_questionStates[indexAtCallTime]?.isRevealed ?? false)) {
        _answerController.jumpTo(answerToSync);
        _answerController.resetVisualState();
      }
    });
  }

  void _onQuestionIndexChanged(int newIndex) {
    final oldIndex = _currentIndex;

    // Clear any ongoing animation state BEFORE changing index
    // This prevents animation callbacks from updating stale question indices
    _animatingQuestionIndex = null;
    _animationProgress.clear();

    // Ensure state is initialized for new question BEFORE updating index
    // This ensures getDisplayAnswer() returns correct value immediately after index change
    if (!_isReviewMode) {
      _ensureQuestionStateInitialized(newIndex);
    }

    // Update current index FIRST - this makes getDisplayAnswer() return correct value
    _currentIndex = newIndex;

    // Reset submitted answer for the new question (state only, no controller sync yet)
    if (!_isReviewMode) {
      _localSubmittedAnswer = null;
    }

    // Sync controller AFTER index is updated (in post-frame callback)
    // This ensures widgets are bound to correct question before controller updates
    if (!_isReviewMode) {
      _syncControllerToCurrentQuestion();
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

    // Stop deadline timer for old question
    if (oldIndex != newIndex) {
      _deadlineProgressTracker?.reset();
      // Cancel auto-next timer when moving to next question
      _cancelAutoNextTimer();
    }

    // Start deadline timer for new question
    if (!_isReviewMode) {
      final state = _questionStates[newIndex];
      if (state != null &&
          !state.isRevealed &&
          _perQuestionDuration.inMilliseconds > 0) {
        _deadlineProgressTracker?.start(_perQuestionDuration,
            onExpired: _handleDeadlineExpired);
      }
    }

    notifyListeners();
  }

  /// Trigger reveal animation for the current question
  /// This consolidates duplicate animation logic from _handleReveal and _handlePlayersAnswers
  /// Color is calculated at animation start time to ensure latest scores are used
  void _triggerRevealAnimation(int index, AnswerValue correctAnswer) {
    AppLogger.debug(
        '_triggerRevealAnimation START: index=$index, currentIndex=$_currentIndex, isReviewMode=$_isReviewMode, reviewModePending=$_reviewModePending');

    if (index != _currentIndex) {
      AppLogger.debug(
          '_triggerRevealAnimation ABORT: index mismatch (index=$index != currentIndex=$_currentIndex)');
      return;
    }

    final state = _questionStates[index];
    if (state == null) {
      AppLogger.debug(
          '_triggerRevealAnimation ABORT: state is null for index=$index');
      return;
    }

    // For last question, allow animation even in review mode or when review mode is pending
    final bool shouldAnimate =
        !_isReviewMode || index == questionCount - 1 || _reviewModePending;
    if (!shouldAnimate) {
      AppLogger.debug(
          '_triggerRevealAnimation ABORT: shouldAnimate=false (isReviewMode=$_isReviewMode, index=$index, questionCount=$questionCount, reviewModePending=$_reviewModePending)');
      return;
    }

    final displayAnswer = _toDisplayAnswer(correctAnswer, state);

    // Use _localSubmittedAnswer as ground truth for starting position
    // This is exactly what the user submitted, guaranteed accurate
    final AnswerValue startValue = _localSubmittedAnswer ??
        state.userAnswer ??
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');

    AppLogger.debug(
        '_triggerRevealAnimation: startValue=$startValue, displayAnswer=$displayAnswer, correctAnswer=$correctAnswer');
    AppLogger.debug(
        '_triggerRevealAnimation: _localSubmittedAnswer=$_localSubmittedAnswer, state.userAnswer=${state.userAnswer}');

    _animatingQuestionIndex = index;
    _animationProgress[index] = startValue;

    AppLogger.debug(
        '_triggerRevealAnimation: Set _animatingQuestionIndex=$index, _animationProgress[$index]=$startValue');

    // Single notifyListeners() call - widget will rebuild once
    notifyListeners();

    final int indexAtStart = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.debug(
          '_triggerRevealAnimation POST-FRAME: indexAtStart=$indexAtStart, _currentIndex=$_currentIndex, _animatingQuestionIndex=$_animatingQuestionIndex');
      AppLogger.debug(
          '_triggerRevealAnimation POST-FRAME: isReviewMode=$_isReviewMode, reviewModePending=$_reviewModePending');

      if (_currentIndex == indexAtStart &&
          _animatingQuestionIndex == indexAtStart &&
          (!_isReviewMode ||
              indexAtStart == questionCount - 1 ||
              _reviewModePending)) {
        final myScore = _getMyScoreForQuestion(indexAtStart) ?? 0;
        final Color revealColor = scoreToColor(myScore);

        AppLogger.debug(
            '_triggerRevealAnimation POST-FRAME: Calling _answerController.reveal()');
        AppLogger.debug(
            '_triggerRevealAnimation POST-FRAME: startValue=$startValue, displayAnswer=$displayAnswer, duration=600ms, color=$revealColor');

        // Pass explicit start and end values
        _answerController.reveal(
          startValue, // Explicit start
          displayAnswer, // Explicit end
          const Duration(milliseconds: 600),
          revealColor,
          onProgress: (progressValue) {
            AppLogger.debug(
                '_triggerRevealAnimation ON-PROGRESS: progressValue=$progressValue');
            updateDisplayAnswer(indexAtStart, progressValue);
          },
          onComplete: () {
            AppLogger.debug(
                '_triggerRevealAnimation ON-COMPLETE: Animation finished for index=$indexAtStart');
            if (_animatingQuestionIndex == indexAtStart) {
              _animatingQuestionIndex = null;
              _animationProgress.remove(indexAtStart);

              // If final question, delay review mode activation
              if (indexAtStart == questionCount - 1 && _reviewModePending) {
                AppLogger.debug(
                    '_triggerRevealAnimation ON-COMPLETE: Scheduling review mode activation (final question)');
                _scheduleReviewModeActivation();
              }
            }
            notifyListeners();
          },
        );
      } else {
        AppLogger.debug(
            '_triggerRevealAnimation POST-FRAME: Conditions not met, cleaning up animation state');
        if (_animatingQuestionIndex == indexAtStart) {
          _animatingQuestionIndex = null;
          _animationProgress.remove(indexAtStart);
        }
      }
    });
  }

  void _scheduleReviewModeActivation() {
    _reviewModeActivationTimer?.cancel();
    _reviewModeActivationTimer = Timer(const Duration(milliseconds: 1000), () {
      if (_reviewModePending) {
        _isReviewMode = true;
        _reviewModePending = false;
        // Trigger confetti check when review mode activates after animation
        // This ensures confetti is shown even if the check was missed earlier
        if (!_confettiShown) {
          _checkAndSetConfetti();
          _scheduleConfettiCheck();
        }
        notifyListeners();
      }
    });
  }

  void _handleReveal(int index, AnswerValue correct) {
    AppLogger.debug(
        '_handleReveal: index=$index, correct=$correct, currentIndex=$_currentIndex');
    final currentState = _questionStates[index] ?? QuestionState();
    final wasRevealed = currentState.isRevealed;
    AppLogger.debug('_handleReveal: wasRevealed=$wasRevealed');
    _questionStates[index] = currentState.copyWith(
      correctAnswer: correct,
      isRevealed: true,
    );

    // Stop deadline timer when revealed
    if (index == _currentIndex) {
      _deadlineProgressTracker?.stop();
    }

    // If this is the current question and it wasn't already revealed, reveal the answer widget
    // Note: _handlePlayersAnswers might have already triggered the reveal, so we check wasRevealed
    // Allow animation even if review mode activates simultaneously (for last question)
    if (index == _currentIndex && !wasRevealed) {
      AppLogger.debug(
          '_handleReveal: Triggering reveal animation (index=$index, wasRevealed=$wasRevealed)');
      _triggerRevealAnimation(index, correct);
    } else {
      AppLogger.debug(
          '_handleReveal: NOT triggering animation (index=$index, currentIndex=$_currentIndex, wasRevealed=$wasRevealed)');
    }

    // Start auto-next timer if not last question and not in review mode
    if (index == _currentIndex && !_isReviewMode && index < questionCount - 1) {
      _startAutoNextTimer();
    }

    // Animation callback will notify listeners when animation completes
  }

  AnswerValue _toDisplayAnswer(AnswerValue raw, QuestionState state) {
    final String idOrAbbr = raw.unit;
    // Try to get abbreviation from ID mapping
    final String abbr = state.unitIdToAbbreviation[idOrAbbr] ?? idOrAbbr;

    // If the answer already has an order of magnitude, just map the unit
    if (raw.orderOfMagnitude.isNotEmpty) {
      return AnswerValue(
        number: raw.number,
        orderOfMagnitude: raw.orderOfMagnitude,
        unit: abbr,
      );
    }

    // Otherwise, decompose the absolute number into number + OM
    return AnswerValue(
      number: raw.number,
      orderOfMagnitude: raw.orderOfMagnitude,
      unit: abbr,
    );
  }

  void _startAutoNextTimer() {
    _cancelAutoNextTimer();

    // Only start timer if conditions are met
    if (_isReviewMode || _isPrivate) {
      return;
    }
    if (_currentIndex >= questionCount - 1) {
      return; // Last question
    }

    // Store the index when timer starts to ensure we only auto-next for the same question
    final int timerQuestionIndex = _currentIndex;

    _autoNextStartedAt = DateTime.now();
    _autoNextProgress = 0.0;
    notifyListeners();

    _autoNextTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Check if timer should still be running
      if (_autoNextStartedAt == null) {
        timer.cancel();
        _autoNextTimer = null;
        _autoNextProgress = 0.0;
        notifyListeners();
        return;
      }

      // Check if we're still in the same conditions
      if (_isReviewMode || _currentIndex != timerQuestionIndex) {
        timer.cancel();
        _autoNextTimer = null;
        _autoNextStartedAt = null;
        _autoNextProgress = 0.0;
        notifyListeners();
        return;
      }

      // Verify question is still revealed
      final currentState = _questionStates[_currentIndex];
      if (currentState == null || !currentState.isRevealed) {
        timer.cancel();
        _autoNextTimer = null;
        _autoNextStartedAt = null;
        _autoNextProgress = 0.0;
        notifyListeners();
        return;
      }

      final elapsed = DateTime.now().difference(_autoNextStartedAt!);
      double progress =
          elapsed.inMilliseconds / _autoNextDuration.inMilliseconds;

      if (progress >= 1.0) {
        progress = 1.0;
        _autoNextProgress = progress;
        notifyListeners();
        timer.cancel();
        _autoNextTimer = null;
        _autoNextStartedAt = null;

        // Auto-trigger next if host
        if (_isHost) {
          requestNext();
        }
        return;
      }

      _autoNextProgress = progress;
      notifyListeners();
    });
  }

  void _cancelAutoNextTimer() {
    _autoNextTimer?.cancel();
    _autoNextTimer = null;
    _autoNextStartedAt = null;
    _autoNextProgress = 0.0;
    notifyListeners(); // Notify UI to update progress indicator
  }

  /// Synchronize the cached `QuestionState.players` list with the latest reveal
  /// snapshot so the widget tree and player controllers observe the same data.
  /// This prevents live-mode fallbacks (e.g., zero scores) from overwriting the
  /// animated totals that were already delivered through the controllers.
  ///
  /// TODO(maintainers): This logic intentionally mirrors `_updatePlayers`. Do not
  /// start a consolidation without explicit direction; the dual paths protect live
  /// fallbacks while reveal snapshots stream in.
  void _applyScoresToPlayerStates({
    required int index,
    required Map<String, AnswerValue> submittedAnswers,
    required Map<String, int> roundScores,
    required Map<String, int> cumulativeScores,
  }) {
    final state = _questionStates[index];
    if (state == null) return;

    final List<PlayerState> existingPlayers = state.players;
    List<PlayerState> updatedPlayers = const [];

    if (existingPlayers.isNotEmpty) {
      updatedPlayers = existingPlayers.map((player) {
        final pid = player.playerId;
        final int? newScore =
            pid != null ? cumulativeScores[pid] ?? player.score : player.score;
        final int? newRoundScore = pid != null
            ? roundScores[pid] ?? player.roundScore
            : player.roundScore;
        final AnswerValue? submitted = pid != null
            ? submittedAnswers[pid] ?? player.submittedAnswer
            : player.submittedAnswer;

        // Compute ring state: only use review if question is revealed, otherwise
        // preserve existing ring state logic (completed if answered, countdown if not)
        RingState ringState;
        if (_isReviewMode || state.isRevealed) {
          ringState = RingState.review;
        } else {
          // Question not revealed yet - check if this player has answered
          final bool hasAnswered = submitted != null;
          ringState = hasAnswered ? RingState.completed : player.ringState;
        }

        return player.copyWith(
          score: newScore,
          roundScore: newRoundScore,
          submittedAnswer: submitted,
          status: PlayerStatus.answer,
          ringState: ringState,
        );
      }).toList(growable: false);
    } else if (_latestPlayerOrder.isNotEmpty) {
      final List<PlayerState> rebuilt = [];
      for (final pid in _latestPlayerOrder) {
        final summary = _latestPlayerSummaries[pid];
        if (summary == null || !summary.isActive) continue;

        // Compute ring state: only use review if question is revealed, otherwise
        // use completed if player has answered, countdown if not
        final AnswerValue? submitted = submittedAnswers[pid];
        RingState ringState;
        if (_isReviewMode || state.isRevealed) {
          ringState = RingState.review;
        } else {
          final bool hasAnswered = submitted != null;
          ringState = hasAnswered ? RingState.completed : RingState.countdown;
        }

        rebuilt.add(
          PlayerState(
            playerId: pid,
            displayName: summary.name,
            avatarUrl: summary.pictureUrl,
            isHost: summary.isHost,
            score: cumulativeScores[pid] ?? 0,
            roundScore: roundScores[pid] ?? 0,
            submittedAnswer: submitted,
            status: PlayerStatus.answer,
            ringState: ringState,
          ),
        );
      }
      updatedPlayers = rebuilt;
    }

    if (updatedPlayers.isNotEmpty) {
      _questionStates[index] = state.copyWith(players: updatedPlayers);
    }
  }

  void _handlePlayersAnswers(int index, PlayersAnswersSnapshot snapshot) {
    final currentState = _questionStates[index] ?? QuestionState();

    // Calculate cumulative scores
    final Map<String, int> cumulativeScores = {};
    final prevCumulative =
        index > 0 ? (_questionStates[index - 1]?.cumulativeScores ?? {}) : {};

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
          _toDisplayAnswer(entry.value, currentState);
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
    _questionStates[index] = currentState.copyWith(
      submittedAnswers: displaySubmittedAnswers,
      scores: snapshot.scores,
      cumulativeScores: cumulativeScores,
      percentiles: snapshot.percentiles,
      isRevealed: shouldBeRevealed,
      correctAnswer: correctAnswer ??
          currentState.correctAnswer, // Preserve existing if not in snapshot
    );

    // Update player controllers with scores.
    // We push both the per-question score (round) and the cumulative total so
    // that score widgets can animate immediately when the reveal snapshot arrives,
    // without waiting for the next game snapshot.
    for (final entry in snapshot.scores.entries) {
      final controller = _playerControllers[entry.key];
      if (controller != null) {
        controller.setRoundScore(roundScores[entry.key] ?? 0);
        final int cumulativeScore =
            cumulativeScores[entry.key] ?? prevCumulative[entry.key] ?? 0;
        controller.setScore(cumulativeScore);
      }
    }

    // Find the highest round score and trigger confetti for that player
    // For the final question, trigger confetti even if review mode is active
    // (since review mode may activate before the final reveal completes)
    if (!_isReviewMode || index == questionCount - 1) {
      int maxRoundScore = 0;
      String? highestScorerId;
      for (final entry in snapshot.scores.entries) {
        final int roundScore = entry.value.round();
        if (roundScore > maxRoundScore) {
          maxRoundScore = roundScore;
          highestScorerId = entry.key;
        }
      }

      // Trigger confetti for the highest scorer (if score > 0)
      // For non-final questions, only trigger when not in review mode
      // For final question, trigger even in review mode to handle transition timing
      if (highestScorerId != null && maxRoundScore > 0) {
        final controller = _playerControllers[highestScorerId];
        controller?.triggerConfetti();
      }
    }

    _applyScoresToPlayerStates(
      index: index,
      submittedAnswers: displaySubmittedAnswers,
      roundScores: roundScores,
      cumulativeScores: cumulativeScores,
    );

    // If animation is currently running for this question, update color with latest scores
    // This handles the case where scores arrive after animation has started
    if (_animatingQuestionIndex == index) {
      final currentState = _questionStates[index];
      if (currentState?.isRevealed == true) {
        // Trigger rebuild to update revealedColor prop (color is computed by getRevealedColor)
        notifyListeners();
      }
    }

    // If this question was just revealed and it's the current question in live mode, trigger reveal animation
    // This handles the case where the reveal stream doesn't emit or emits before the widget is ready
    // Allow animation even if review mode activates simultaneously (for last question)
    if (!wasRevealed && index == _currentIndex && correctAnswer != null) {
      AppLogger.debug(
          '_handlePlayersAnswers: Triggering reveal animation (index=$index, wasRevealed=$wasRevealed, correctAnswer=$correctAnswer)');
      _triggerRevealAnimation(index, correctAnswer);
    } else {
      AppLogger.debug(
          '_handlePlayersAnswers: NOT triggering animation (index=$index, currentIndex=$_currentIndex, wasRevealed=$wasRevealed, correctAnswer=$correctAnswer)');
    }

    // Start auto-next timer if this question was just revealed and it's the current question
    if (!wasRevealed &&
        index == _currentIndex &&
        !_isReviewMode &&
        index < questionCount - 1) {
      _startAutoNextTimer();
    }

    // Check confetti if this is the last question and we're in review mode or pending
    // This handles the case where PlayersAnswersSnapshot arrives after GameSnapshot
    // Also handles the case where review mode is pending (final animation in progress)
    if (index == questionCount - 1 && (_isReviewMode || _reviewModePending)) {
      _checkAndSetConfetti();
      _scheduleConfettiCheck(); // Also try on next frame to handle race conditions

      // Calculate final ranks if not already calculated (handles case where scores arrive after review mode activates)
      if (_finalRanks == null && cumulativeScores.isNotEmpty) {
        final List<MapEntry<String, int>> sortedScores =
            cumulativeScores.entries.toList()
              ..sort((a, b) {
                if (a.value != b.value) {
                  return b.value.compareTo(a.value); // Descending order
                }
                // Tiebreaker: use playerId for stable sort
                return a.key.compareTo(b.key);
              });
        // Take top 3 and map their playerId to Rank enum
        _finalRanks = <String, Rank>{};
        for (int i = 0; i < sortedScores.length && i < 3; i++) {
          final entry = sortedScores[i];
          final String playerId = entry.key;
          switch (i) {
            case 0:
              _finalRanks![playerId] = Rank.first;
              break;
            case 1:
              _finalRanks![playerId] = Rank.second;
              break;
            case 2:
              _finalRanks![playerId] = Rank.third;
              break;
          }
        }
        notifyListeners();
      }
    }

    // Animation callback will notify listeners when animation completes
    // Players will be updated when game snapshot arrives with player summaries
  }

  int? _getMyScoreForQuestion(int index) {
    final state = _questionStates[index];
    if (state == null) return null;
    final myId = realtime.currentPlayerId;
    final score = state.scores[myId];
    return score?.round();
  }

  /// Handle carousel page change (user swipe in review mode)
  void onCarouselPageChanged(int index) {
    if (_isReviewMode && index != _currentIndex) {
      _currentIndex = index;

      // Clear any ongoing animation state
      _animatingQuestionIndex = null;
      _animationProgress.clear();

      _updatePlayersForIndex(index);
      notifyListeners();
    }
  }

  void _updatePlayersForIndex(int index) {
    final state = _questionStates[index];
    if (state == null) return;

    // Update player controllers with scores for this question
    // Players are already sorted by rank in state.players
    for (final playerState in state.players) {
      final playerId = playerState.playerId;
      if (playerId == null) continue;
      final controller = _playerControllers[playerId];
      if (controller != null) {
        // Use setScore to animate to the cumulative score for this question
        controller.setScore(playerState.score ?? 0);
        // Also update round score
        controller.setRoundScore(playerState.roundScore ?? 0);
      }
    }
  }

  /// Submit answer for current question
  Future<void> submitAnswer() async {
    if (_isReviewMode) return;
    if (_localSubmittedAnswer != null) return; // Already submitted

    // Don't stop the deadline timer - it should continue for other players
    // The timer will stop when all players have answered or deadline expires

    final state = _questionStates[_currentIndex];
    if (state == null) return;

    // Wait for unit maps if not available yet
    if (state.unitAbbreviationToId.isEmpty && state.units.isNotEmpty) {
      // Unit maps not ready yet, queue submission
      _errorMessage = 'Please wait for question to load...';
      notifyListeners();
      return;
    }

    // Get user answer from state
    final AnswerValue currentAnswer = state.userAnswer ??
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');

    // Store UI answer (with abbreviation) for display purposes
    _localSubmittedAnswer = currentAnswer;

    // Convert UI answer to submission format (with unit ID) for backend
    final AnswerValue toSubmit = _convertForSubmission(currentAnswer, state);

    try {
      await realtime.submitAnswer(gameId, _currentIndex, toSubmit);
      _errorMessage = null; // Clear any previous error
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Submit failed. Please check your connection.';
      notifyListeners();
    }
  }

  AnswerValue _convertForSubmission(AnswerValue uiValue, QuestionState state) {
    final String abbr = uiValue.unit;
    if (abbr.isEmpty) {
      return uiValue;
    }
    final String? id = state.unitAbbreviationToId[abbr];
    if (id == null || id.isEmpty) return uiValue;
    return AnswerValue(
      number: uiValue.number,
      orderOfMagnitude: uiValue.orderOfMagnitude,
      unit: id,
    );
  }

  /// Handle answer input changes
  /// Updates the user answer directly in state for the current question
  void onAnswerChanged(AnswerValue value) {
    // Ensure state exists for current question (create if needed)
    final state = _questionStates[_currentIndex] ?? QuestionState();
    _questionStates[_currentIndex] = state.copyWith(userAnswer: value);
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
    final state = _questionStates[_currentIndex];
    if (state == null || state.questionUid == null) return;
    await realtime.upvoteQuestion(state.questionUid!);
    _questionStates[_currentIndex] = state.copyWith(
      upvotes: state.upvotes + 1,
      voteState: VoteState.upvoted,
    );
    notifyListeners();
  }

  Future<void> onDeUpvote() async {
    final state = _questionStates[_currentIndex];
    if (state == null || state.questionUid == null) return;
    await realtime.deUpvoteQuestion(state.questionUid!);
    _questionStates[_currentIndex] = state.copyWith(
      upvotes: (state.upvotes - 1).clamp(0, double.infinity).toInt(),
      voteState: VoteState.none,
    );
    notifyListeners();
  }

  Future<void> onDownvote() async {
    final state = _questionStates[_currentIndex];
    if (state == null || state.questionUid == null) return;
    await realtime.downvoteQuestion(state.questionUid!);
    _questionStates[_currentIndex] = state.copyWith(
      voteState: VoteState.downvoted,
    );
    notifyListeners();
  }

  Future<void> onDeDownvote() async {
    final state = _questionStates[_currentIndex];
    if (state == null || state.questionUid == null) return;
    await realtime.deDownvoteQuestion(state.questionUid!);
    _questionStates[_currentIndex] = state.copyWith(
      voteState: VoteState.none,
    );
    notifyListeners();
  }

  /// Clear confetti after it has been shown (called when animation completes).
  /// Note: Confetti state persists across carousel navigation in review mode
  /// (scrolling between questions) as it's a game-end effect, not per-question.
  void clearConfetti() {
    _confettiRank = null;
    notifyListeners();
  }

  /// Request next question (host only)
  Future<void> requestNext() async {
    if (!_isHost || _isReviewMode) return;
    _cancelAutoNextTimer();
    try {
      await realtime.goNext(gameId);
    } catch (e) {
      _errorMessage = 'Failed to request next. Please try again.';
      notifyListeners();
    }
  }

  /// Get score color for revealed answer
  Color? getRevealedColor(int index) {
    final state = _questionStates[index];
    if (state == null || !state.isRevealed) return null;
    final myId = realtime.currentPlayerId;
    final score = state.scores[myId];
    return scoreToColor(score?.round() ?? 0);
  }

  /// Get display-formatted correct answer for a question index
  AnswerValue? getRevealedAnswer(int index) {
    final state = _questionStates[index];
    if (state == null || !state.isRevealed || state.correctAnswer == null) {
      return null;
    }
    return _toDisplayAnswer(state.correctAnswer!, state);
  }

  /// Get player's percentile for a question index
  double? getMyPercentileForIndex(int index) {
    final state = _questionStates[index];
    if (state == null || !state.isRevealed) return null;
    final myId = realtime.currentPlayerId;
    return state.percentiles[myId];
  }

  /// Get category for a question index
  String? getCategoryForIndex(int index) {
    final state = _questionStates[index];
    return state?.category;
  }

  /// Check if a question is revealed (for onboarding tutorial)
  bool isQuestionRevealed(int index) {
    final state = _questionStates[index];
    return state?.isRevealed ?? false;
  }

  @override
  void dispose() {
    _gameSub?.cancel();
    _cancelAutoNextTimer();
    _reviewModeActivationTimer?.cancel();
    _deadlineProgressTracker?.dispose();
    _unitOptionsNotifier.dispose();
    for (final bindings in _bindingsByIndex.values) {
      bindings.dispose();
    }
    _bindingsByIndex.clear();
    for (final controller in _playerControllers.values) {
      controller.dispose();
    }
    _playerControllers.clear();
    super.dispose();
  }
}
