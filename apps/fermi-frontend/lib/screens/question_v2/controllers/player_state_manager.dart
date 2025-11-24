import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/player_widget_controller.dart';
import 'package:fermi_frontend/screens/question_v2/controllers/question_state_manager.dart';

/// Manages player controllers, player summaries, and player state updates.
///
/// This manager is responsible for:
/// - Creating and disposing player widget controllers
/// - Updating player states from game snapshots
/// - Applying scores to player states
/// - Managing player order and summaries
class PlayerStateManager {
  // Player controllers: playerId -> controller
  final Map<String, PlayerWidgetController> _playerControllers = {};
  Map<String, PlayerSummary> _latestPlayerSummaries = {};
  List<String> _latestPlayerOrder = const [];

  /// Get player controllers map
  Map<String, PlayerWidgetController> get playerControllers =>
      _playerControllers;

  /// Get players state for a question index (for PlayersRow)
  List<PlayerState> getPlayersForIndex(
      int index, QuestionStateManager stateManager) {
    final state = stateManager.getQuestionState(index);
    if (state != null && state.players.isNotEmpty) {
      return state.players;
    }
    // Fallback: return empty list or initial players
    return const [];
  }

  /// Update players from game snapshot
  void updatePlayers({
    required GameSnapshot snapshot,
    required QuestionStateManager stateManager,
    required bool isReviewMode,
    required int currentIndex,
    required int questionCount,
  }) {
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

    // TODO(maintainers): This block mirrors `applyScoresToPlayerStates`. Keep both
    // in sync until we explicitly refactor the player mapping pipeline. Please do
    // not attempt that cleanup unless product/design asks for it; the current flow
    // relies on these live-mode fallbacks.
    // Update player states for current question (live mode) or all revealed questions (review mode)
    final int targetIndex = isReviewMode ? currentIndex : currentIndex;
    final state = stateManager.getQuestionState(targetIndex);

    if (state != null) {
      // Get previous question's cumulative scores as fallback for score continuity
      final Map<String, int> prevCumulativeScores = {};
      if (!isReviewMode && targetIndex > 0) {
        final prevState = stateManager.getQuestionState(targetIndex - 1);
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
        if (isReviewMode || state.isRevealed) {
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

      stateManager.updateQuestionState(
          targetIndex, state.copyWith(players: players));
    }

    // Also update all revealed questions in review mode
    if (isReviewMode) {
      for (int i = 0; i < questionCount; i++) {
        if (i == targetIndex) continue; // Already updated above
        final state = stateManager.getQuestionState(i);
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

        stateManager.updateQuestionState(i, state.copyWith(players: players));
      }
    }
  }

  /// Synchronize the cached `QuestionState.players` list with the latest reveal
  /// snapshot so the widget tree and player controllers observe the same data.
  /// This prevents live-mode fallbacks (e.g., zero scores) from overwriting the
  /// animated totals that were already delivered through the controllers.
  ///
  /// TODO(maintainers): This logic intentionally mirrors `updatePlayers`. Do not
  /// start a consolidation without explicit direction; the dual paths protect live
  /// fallbacks while reveal snapshots stream in.
  void applyScoresToPlayerStates({
    required int index,
    required Map<String, AnswerValue> submittedAnswers,
    required Map<String, int> roundScores,
    required Map<String, int> cumulativeScores,
    required QuestionStateManager stateManager,
    required bool isReviewMode,
  }) {
    final state = stateManager.getQuestionState(index);
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
        if (isReviewMode || state.isRevealed) {
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
        if (isReviewMode || state.isRevealed) {
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
      stateManager.updateQuestionState(
          index, state.copyWith(players: updatedPlayers));
    }
  }

  /// Update player controllers with scores for a specific question index
  void updatePlayersForIndex(int index, QuestionStateManager stateManager) {
    final state = stateManager.getQuestionState(index);
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

  /// Get player's score for a question
  int? getMyScoreForQuestion(
      int index, String myPlayerId, QuestionStateManager stateManager) {
    final state = stateManager.getQuestionState(index);
    if (state == null) return null;
    final score = state.scores[myPlayerId];
    return score?.round();
  }

  /// Dispose all player controllers
  void dispose() {
    for (final controller in _playerControllers.values) {
      controller.dispose();
    }
    _playerControllers.clear();
  }
}
