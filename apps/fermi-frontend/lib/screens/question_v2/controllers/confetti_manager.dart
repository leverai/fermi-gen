import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/rank.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/question_state_manager.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/player_state_manager.dart';

/// Manages game-end confetti state and per-question confetti triggers.
///
/// This manager is responsible for:
/// - Tracking confetti rank for the current player
/// - Calculating final ranks for top 3 players
/// - Triggering per-question confetti for highest scorers
/// - Managing confetti shown state to prevent duplicates
class ConfettiManager {
  int? _confettiRank; // tracks rank (1, 2, or 3) for game-end confetti
  Map<String, Rank>? _finalRanks; // Final ranks for top 3 players
  bool _confettiShown = false; // prevents duplicate confetti triggers

  int? get confettiRank => _confettiRank;
  Map<String, Rank>? get finalRanks => _finalRanks;

  /// Check if confetti should be shown for the current player
  void checkAndSetConfetti({
    required int questionCount,
    required QuestionStateManager stateManager,
    required String myPlayerId,
    required VoidCallback onUpdate,
  }) {
    if (_confettiShown) return;

    if (myPlayerId.isEmpty) return;

    // Get cumulative scores from the last question's state
    final lastQuestionState = stateManager.getQuestionState(questionCount - 1);

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
    final int myIndex =
        sortedScores.indexWhere((entry) => entry.key == myPlayerId);

    if (myIndex >= 0 && myIndex < 3) {
      final int myRank = myIndex + 1; // Convert 0-based index to 1-based rank
      _confettiRank = myRank;
      _confettiShown = true;
      onUpdate();
    }
  }

  /// Schedule confetti check on next frame to avoid race conditions
  void scheduleConfettiCheck({
    required int questionCount,
    required QuestionStateManager stateManager,
    required String myPlayerId,
    required VoidCallback onUpdate,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndSetConfetti(
        questionCount: questionCount,
        stateManager: stateManager,
        myPlayerId: myPlayerId,
        onUpdate: onUpdate,
      );
    });
  }

  /// Trigger confetti for the player with the highest round score
  void triggerPerQuestionConfetti({
    required int index,
    required Map<String, double> scores,
    required PlayerStateManager playerStateManager,
    required bool isReviewMode,
    required int questionCount,
  }) {
    // For the final question, trigger confetti even if review mode is active
    // (since review mode may activate before the final reveal completes)
    if (!isReviewMode || index == questionCount - 1) {
      int maxRoundScore = 0;
      String? highestScorerId;
      for (final entry in scores.entries) {
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
        final controller =
            playerStateManager.playerControllers[highestScorerId];
        controller?.triggerConfetti();
      }
    }
  }

  /// Calculate final ranks for top 3 players when review mode activates
  /// This ensures rank icons remain static during reordering in review mode
  void calculateFinalRanks({
    required int questionCount,
    required QuestionStateManager stateManager,
    required VoidCallback onUpdate,
  }) {
    if (_finalRanks != null) return; // Already calculated

    final lastQuestionState = stateManager.getQuestionState(questionCount - 1);
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
      onUpdate();
    }
  }

  /// Calculate final ranks from cumulative scores (used when scores arrive after review mode)
  void calculateFinalRanksFromScores({
    required Map<String, int> cumulativeScores,
    required VoidCallback onUpdate,
  }) {
    if (_finalRanks != null || cumulativeScores.isEmpty) return;

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
    onUpdate();
  }

  /// Clear confetti after it has been shown (called when animation completes)
  /// Note: Confetti state persists across carousel navigation in review mode
  /// (scrolling between questions) as it's a game-end effect, not per-question.
  void clearConfetti(VoidCallback onUpdate) {
    _confettiRank = null;
    onUpdate();
  }

  /// Reset confetti state (for new game)
  void reset() {
    _confettiRank = null;
    _finalRanks = null;
    _confettiShown = false;
  }
}
