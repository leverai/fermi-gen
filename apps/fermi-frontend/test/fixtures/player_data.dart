import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';

/// Factory functions for creating player data for testing.
///
/// Provides reusable player summaries, states, and score distributions
/// for single-player and multi-player scenarios. All data is pure Dart.
class PlayerDataFixtures {
  /// Creates a single player summary (host).
  static PlayerSummary singlePlayer({
    String? playerId,
    String? name,
    double score = 0.0,
    int? rank,
    bool isActive = true,
  }) {
    return PlayerSummary(
      playerId: playerId ?? 'player_1',
      name: name ?? 'Test Player',
      pictureUrl: null,
      score: score,
      isHost: true,
      isActive: isActive,
      rank: rank,
    );
  }

  /// Creates a player summary for a non-host player.
  static PlayerSummary player({
    required String playerId,
    String? name,
    double score = 0.0,
    int? rank,
    bool isHost = false,
    bool isActive = true,
    String? pictureUrl,
  }) {
    return PlayerSummary(
      playerId: playerId,
      name: name ?? 'Player $playerId',
      pictureUrl: pictureUrl,
      score: score,
      isHost: isHost,
      isActive: isActive,
      rank: rank,
    );
  }

  /// Creates a map of 3 players with different scores.
  static Map<String, PlayerSummary> threePlayers({
    String? currentPlayerId,
    double player1Score = 20.0,
    double player2Score = 15.0,
    double player3Score = 10.0,
  }) {
    return {
      'player_1': PlayerSummary(
        playerId: 'player_1',
        name: 'Alice',
        score: player1Score,
        isHost: true,
        isActive: true,
        rank: 1,
      ),
      'player_2': PlayerSummary(
        playerId: 'player_2',
        name: 'Bob',
        score: player2Score,
        isHost: false,
        isActive: true,
        rank: 2,
      ),
      'player_3': PlayerSummary(
        playerId: 'player_3',
        name: 'Charlie',
        score: player3Score,
        isHost: false,
        isActive: true,
        rank: 3,
      ),
    };
  }

  /// Creates a map of 4 players with tied scores.
  static Map<String, PlayerSummary> fourPlayersWithTies({
    String? currentPlayerId,
  }) {
    return {
      'player_1': const PlayerSummary(
        playerId: 'player_1',
        name: 'Alice',
        score: 20.0,
        isHost: true,
        isActive: true,
        rank: 1,
      ),
      'player_2': const PlayerSummary(
        playerId: 'player_2',
        name: 'Bob',
        score: 20.0,
        isHost: false,
        isActive: true,
        rank: 1, // Tie for first
      ),
      'player_3': const PlayerSummary(
        playerId: 'player_3',
        name: 'Charlie',
        score: 15.0,
        isHost: false,
        isActive: true,
        rank: 3,
      ),
      'player_4': const PlayerSummary(
        playerId: 'player_4',
        name: 'Diana',
        score: 10.0,
        isHost: false,
        isActive: true,
        rank: 4,
      ),
    };
  }

  /// Creates a map of players with one inactive player.
  static Map<String, PlayerSummary> playersWithInactive({
    String? currentPlayerId,
  }) {
    return {
      'player_1': const PlayerSummary(
        playerId: 'player_1',
        name: 'Alice',
        score: 20.0,
        isHost: true,
        isActive: true,
        rank: 1,
      ),
      'player_2': const PlayerSummary(
        playerId: 'player_2',
        name: 'Bob',
        score: 15.0,
        isHost: false,
        isActive: true,
        rank: 2,
      ),
      'player_3': const PlayerSummary(
        playerId: 'player_3',
        name: 'Charlie',
        score: 10.0,
        isHost: false,
        isActive: false, // Inactive
        rank: null,
      ),
    };
  }

  /// Creates a PlayerState for waiting status.
  static PlayerState waitingPlayerState({
    String? playerId,
    String? displayName,
    bool isHost = false,
    int? score,
  }) {
    return PlayerState(
      playerId: playerId ?? 'player_1',
      displayName: displayName ?? 'Test Player',
      isHost: isHost,
      status: PlayerStatus.waiting,
      score: score,
      ringState: RingState.countdown,
    );
  }

  /// Creates a PlayerState for ready status (answered).
  static PlayerState readyPlayerState({
    String? playerId,
    String? displayName,
    bool isHost = false,
    int? score,
    AnswerValue? submittedAnswer,
  }) {
    return PlayerState(
      playerId: playerId ?? 'player_1',
      displayName: displayName ?? 'Test Player',
      isHost: isHost,
      status: PlayerStatus.ready,
      score: score,
      submittedAnswer: submittedAnswer,
      ringState: RingState.completed,
    );
  }

  /// Creates a PlayerState for revealed answer status.
  static PlayerState answerPlayerState({
    String? playerId,
    String? displayName,
    bool isHost = false,
    int? score,
    int? roundScore,
    AnswerValue? submittedAnswer,
  }) {
    return PlayerState(
      playerId: playerId ?? 'player_1',
      displayName: displayName ?? 'Test Player',
      isHost: isHost,
      status: PlayerStatus.answer,
      score: score,
      roundScore: roundScore,
      submittedAnswer: submittedAnswer,
      ringState: RingState.completed,
    );
  }

  /// Creates a PlayerState for review mode.
  static PlayerState reviewPlayerState({
    String? playerId,
    String? displayName,
    bool isHost = false,
    int? score,
    int? roundScore,
    AnswerValue? submittedAnswer,
  }) {
    return PlayerState(
      playerId: playerId ?? 'player_1',
      displayName: displayName ?? 'Test Player',
      isHost: isHost,
      status: PlayerStatus.answer,
      score: score,
      roundScore: roundScore,
      submittedAnswer: submittedAnswer,
      ringState: RingState.review,
    );
  }

  /// Creates a map of player IDs to submitted answers.
  static Map<String, AnswerValue> submittedAnswers({
    String? player1Id,
    String? player2Id,
    String? player3Id,
  }) {
    return {
      player1Id ?? 'player_1': const AnswerValue(
        number: 8,
        orderOfMagnitude: 'M',
        unit: 'p',
      ),
      player2Id ?? 'player_2': const AnswerValue(
        number: 7,
        orderOfMagnitude: 'M',
        unit: 'p',
      ),
      player3Id ?? 'player_3': const AnswerValue(
        number: 9,
        orderOfMagnitude: 'M',
        unit: 'p',
      ),
    };
  }

  /// Creates a map of player IDs to scores.
  static Map<String, double> playerScores({
    String? player1Id,
    String? player2Id,
    String? player3Id,
    double player1Score = 10.0,
    double player2Score = 8.0,
    double player3Score = 5.0,
  }) {
    return {
      player1Id ?? 'player_1': player1Score,
      player2Id ?? 'player_2': player2Score,
      player3Id ?? 'player_3': player3Score,
    };
  }

  /// Creates a map of player IDs to cumulative scores (integers).
  static Map<String, int> cumulativeScores({
    String? player1Id,
    String? player2Id,
    String? player3Id,
    int player1Score = 20,
    int player2Score = 15,
    int player3Score = 10,
  }) {
    return {
      player1Id ?? 'player_1': player1Score,
      player2Id ?? 'player_2': player2Score,
      player3Id ?? 'player_3': player3Score,
    };
  }

  /// Creates a map of player IDs to percentiles (0.0 to 1.0).
  static Map<String, double> playerPercentiles({
    String? player1Id,
    String? player2Id,
    String? player3Id,
    double player1Percentile = 0.95,
    double player2Percentile = 0.65,
    double player3Percentile = 0.25,
  }) {
    return {
      player1Id ?? 'player_1': player1Percentile,
      player2Id ?? 'player_2': player2Percentile,
      player3Id ?? 'player_3': player3Percentile,
    };
  }

  /// Creates a progress answered map (playerId -> bool).
  static Map<String, bool> progressAnswered({
    String? player1Id,
    String? player2Id,
    String? player3Id,
    bool player1Answered = true,
    bool player2Answered = false,
    bool player3Answered = false,
  }) {
    return {
      player1Id ?? 'player_1': player1Answered,
      player2Id ?? 'player_2': player2Answered,
      player3Id ?? 'player_3': player3Answered,
    };
  }

  /// Creates a progress answered map where all players have answered.
  static Map<String, bool> allPlayersAnswered({
    String? player1Id,
    String? player2Id,
    String? player3Id,
  }) {
    return {
      player1Id ?? 'player_1': true,
      player2Id ?? 'player_2': true,
      player3Id ?? 'player_3': true,
    };
  }
}
