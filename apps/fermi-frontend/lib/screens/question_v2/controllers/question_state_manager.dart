import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/screens/question_v2/models/question_state.dart';
import 'package:fermi_frontend/utils/logger.dart';

/// Manages the question state cache and provides state query methods.
///
/// This manager is responsible for:
/// - Storing and retrieving question states by index
/// - Managing animation state for reveal animations
/// - Providing display answers with correct priority logic
/// - Handling user answer updates
class QuestionStateManager {
  QuestionStateManager({
    required int currentIndex,
  }) : _currentIndex = currentIndex;

  // Historical state cache: index -> QuestionState
  final Map<int, QuestionState> _questionStates = {};

  // Animation progress tracking (ONLY used during active reveal animations)
  int? _animatingQuestionIndex;
  final Map<int, AnswerValue> _animationProgress = {};

  // Current index reference (not owned, updated externally)
  int _currentIndex;

  /// Update the current index reference
  void setCurrentIndex(int index) {
    _currentIndex = index;
  }

  /// Get the cached state for a question index
  QuestionState? getQuestionState(int index) {
    return _questionStates[index];
  }

  /// Get the display answer for a question index
  /// This is a pure function that computes the display value from state
  /// Priority: animation progress > revealed answer > user answer > default
  AnswerValue getDisplayAnswer(int index,
      {AnswerValue? localSubmittedAnswer, required bool isReviewMode}) {
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
      // Use localSubmittedAnswer if available (for current question), otherwise fall back to state.userAnswer
      if (state != null && isCurrentQuestion) {
        final start = localSubmittedAnswer ??
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
    if (isCurrentQuestion && !isReviewMode && !showFeedback) {
      // Ensure state exists and is initialized
      if (state == null) {
        // State doesn't exist yet - return default
        AppLogger.debug(
            'getDisplayAnswer[$index]: Priority 3 (default, state null)');
        return const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
      }

      // If userAnswer is null or has empty unit but units are available, initialize it now
      // This handles lazy initialization when getDisplayAnswer is called before ensureQuestionStateInitialized
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
    }
    // Silently ignore updates for non-animating questions (prevents stale values)
  }

  /// Get display-formatted correct answer for a question index
  AnswerValue? getRevealedAnswer(int index) {
    final state = _questionStates[index];
    if (state == null || !state.isRevealed || state.correctAnswer == null) {
      return null;
    }
    return _toDisplayAnswer(state.correctAnswer!, state);
  }

  /// Convert raw answer to display format (map unit ID to abbreviation)
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

  /// Ensure question state exists and has a userAnswer initialized (if needed)
  /// This only initializes state, does NOT sync controller
  /// Only initializes when units are available to ensure correct default unit
  void ensureQuestionStateInitialized(int index) {
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

  /// Update question state at given index
  void updateQuestionState(int index, QuestionState state) {
    _questionStates[index] = state;
  }

  /// Initialize empty question states for all questions
  void initializeQuestionStates(int questionCount) {
    for (int i = 0; i < questionCount; i++) {
      if (!_questionStates.containsKey(i)) {
        _questionStates[i] = QuestionState();
      }
    }
  }

  /// Handle answer input changes
  /// Updates the user answer directly in state for the given question
  void onAnswerChanged(int index, AnswerValue value) {
    final state = _questionStates[index] ?? QuestionState();
    _questionStates[index] = state.copyWith(userAnswer: value);
  }

  /// Get player's percentile for a question index
  double? getMyPercentileForIndex(int index, String myPlayerId) {
    final state = _questionStates[index];
    if (state == null || !state.isRevealed) return null;
    return state.percentiles[myPlayerId];
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

  /// Get animation state
  int? get animatingQuestionIndex => _animatingQuestionIndex;

  /// Set animation state (called by AnimationStateManager)
  void setAnimatingQuestionIndex(int? index) {
    _animatingQuestionIndex = index;
  }

  /// Clear animation progress for a question
  void clearAnimationProgress(int index) {
    _animationProgress.remove(index);
  }

  /// Clear all animation state
  void clearAllAnimationState() {
    _animatingQuestionIndex = null;
    _animationProgress.clear();
  }
}
