import 'package:flutter/foundation.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/question_state_manager.dart';
import 'package:fermi_frontend/screens/question_v2/models/question_state.dart';

/// Handles answer submission logic, validation, and conversion.
///
/// This handler is responsible for:
/// - Submitting answers with proper validation
/// - Converting UI answers to submission format (abbreviation -> ID)
/// - Handling deadline auto-submit
/// - Applying fallbacks (default unit, minimum number)
class AnswerSubmissionHandler {
  AnswerValue? _localSubmittedAnswer;

  AnswerValue? get localSubmittedAnswer => _localSubmittedAnswer;

  /// Clear local submitted answer (called when navigating to new question)
  void clearLocalSubmittedAnswer() {
    _localSubmittedAnswer = null;
  }

  /// Submit answer for current question
  Future<void> submitAnswer({
    required int currentIndex,
    required QuestionStateManager stateManager,
    required GameRealtime realtime,
    required String gameId,
    required bool isReviewMode,
    required Function(String) onError,
    required VoidCallback onSuccess,
  }) async {
    if (isReviewMode) return;
    if (_localSubmittedAnswer != null) return; // Already submitted

    final state = stateManager.getQuestionState(currentIndex);
    if (state == null) return;

    // Wait for unit maps if not available yet
    if (state.unitAbbreviationToId.isEmpty && state.units.isNotEmpty) {
      // Unit maps not ready yet, queue submission
      onError('Please wait for question to load...');
      return;
    }

    // Get user answer from state, with proper fallback
    // If userAnswer is null or has empty unit but units are available, use first unit
    AnswerValue currentAnswer = state.userAnswer ??
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');

    // Ensure answer has a valid unit if units are available
    // This handles the case where user submits without interacting with the scale widget
    if (currentAnswer.unit.isEmpty && state.units.isNotEmpty) {
      currentAnswer = AnswerValue(
        number: currentAnswer.number,
        orderOfMagnitude: currentAnswer.orderOfMagnitude,
        unit: state.units.first,
      );
    }

    // Store UI answer (with abbreviation) for display purposes
    _localSubmittedAnswer = currentAnswer;

    // Convert UI answer to submission format (with unit ID) for backend
    final AnswerValue toSubmit = _convertForSubmission(currentAnswer, state);

    try {
      await realtime.submitAnswer(gameId, currentIndex, toSubmit);
      onSuccess();
    } catch (e) {
      onError('Submit failed. Please check your connection.');
    }
  }

  /// Handle deadline expiration - auto-submit current answer
  Future<void> handleDeadlineExpired({
    required int currentIndex,
    required QuestionStateManager stateManager,
    required GameRealtime realtime,
    required String gameId,
    required bool isReviewMode,
    required Function(String) onError,
    required VoidCallback onSuccess,
  }) async {
    if (isReviewMode) return;
    if (_localSubmittedAnswer != null) return; // Already submitted

    final state = stateManager.getQuestionState(currentIndex);
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
      await _submitAnswerValue(
        fallbackAnswer,
        state,
        realtime: realtime,
        gameId: gameId,
        currentIndex: currentIndex,
        onError: onError,
        onSuccess: onSuccess,
      );
    } else {
      // Unit map is ready or no unit needed - submit directly
      await _submitAnswerValue(
        withFallbacks,
        state,
        realtime: realtime,
        gameId: gameId,
        currentIndex: currentIndex,
        onError: onError,
        onSuccess: onSuccess,
      );
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
    AnswerValue answerValue,
    QuestionState state, {
    required GameRealtime realtime,
    required String gameId,
    required int currentIndex,
    required Function(String) onError,
    required VoidCallback onSuccess,
  }) async {
    _localSubmittedAnswer = answerValue;

    // Convert UI answer to submission format
    final AnswerValue toSubmit = _convertForSubmission(answerValue, state);

    try {
      await realtime.submitAnswer(gameId, currentIndex, toSubmit);
      onSuccess();
    } catch (e) {
      onError('Auto-submit failed. Please check your connection.');
      _localSubmittedAnswer = null; // Reset on error
    }
  }

  /// Convert UI answer (with abbreviation) to submission format (with unit ID)
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
}
