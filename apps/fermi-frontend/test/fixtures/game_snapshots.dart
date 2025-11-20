import 'package:fermi_frontend/services/game_realtime.dart';

/// Factory functions for creating GameSnapshot objects for testing.
///
/// These fixtures provide reusable game state snapshots for unit, widget,
/// and integration tests. All factories return pure Dart data with no
/// external dependencies.
class GameSnapshotFixtures {
  /// Creates a lobby snapshot in "not ready" state (waiting for players).
  static GameSnapshot lobbyNotReady({
    String? gameId,
    String? currentPlayerId,
    bool isPrivate = false,
    String? joinUrl,
    Map<String, PlayerSummary>? players,
    int nQuestions = 5,
  }) {
    final playerId = currentPlayerId ?? 'player_1';
    final playersMap = players ??
        {
          playerId: PlayerSummary(
            playerId: playerId,
            name: 'Test Player',
            score: 0.0,
            isHost: true,
            isActive: true,
            rank: null,
          ),
        };

    return GameSnapshot(
      state: GameState.lobbyNotReady,
      isHost: playersMap[playerId]?.isHost ?? false,
      questionNumber: 0,
      nQuestions: nQuestions,
      durationSeconds: 0,
      players: playersMap,
      isPrivate: isPrivate,
      joinUrl: joinUrl,
      progressAnswered: const <String, bool>{},
      allAnswered: false,
      currentQuestionUid: null,
      questionUids: [],
    );
  }

  /// Creates a lobby snapshot in "ready" state (can start game).
  static GameSnapshot lobbyReady({
    String? gameId,
    String? currentPlayerId,
    bool isPrivate = false,
    String? joinUrl,
    Map<String, PlayerSummary>? players,
    int nQuestions = 5,
  }) {
    final playerId = currentPlayerId ?? 'player_1';
    final playersMap = players ??
        {
          playerId: PlayerSummary(
            playerId: playerId,
            name: 'Test Player',
            score: 0.0,
            isHost: true,
            isActive: true,
            rank: null,
          ),
        };

    return GameSnapshot(
      state: GameState.lobbyReady,
      isHost: playersMap[playerId]?.isHost ?? false,
      questionNumber: 0,
      nQuestions: nQuestions,
      durationSeconds: 0,
      players: playersMap,
      isPrivate: isPrivate,
      joinUrl: joinUrl,
      progressAnswered: const <String, bool>{},
      allAnswered: false,
      currentQuestionUid: null,
      questionUids: [],
    );
  }

  /// Creates a snapshot for an active question (not the last one).
  static GameSnapshot questionN({
    String? gameId,
    String? currentPlayerId,
    int questionNumber = 1,
    int nQuestions = 5,
    String? questionUid,
    List<String>? questionUids,
    int durationSeconds = 15,
    Map<String, PlayerSummary>? players,
    Map<String, bool>? progressAnswered,
    bool allAnswered = false,
    bool isHost = true,
  }) {
    final playerId = currentPlayerId ?? 'player_1';
    final playersMap = players ??
        {
          playerId: PlayerSummary(
            playerId: playerId,
            name: 'Test Player',
            score: 0.0,
            isHost: isHost,
            isActive: true,
            rank: null,
          ),
        };

    final qUid = questionUid ?? 'question_$questionNumber';
    final qUids =
        questionUids ?? List.generate(nQuestions, (i) => 'question_${i + 1}');

    return GameSnapshot(
      state: GameState.questionN,
      isHost: isHost,
      questionNumber: questionNumber,
      nQuestions: nQuestions,
      durationSeconds: durationSeconds,
      players: playersMap,
      isPrivate: false,
      progressAnswered: progressAnswered ?? const <String, bool>{},
      allAnswered: allAnswered,
      currentQuestionUid: qUid,
      questionUids: qUids,
    );
  }

  /// Creates a snapshot for a finished question (not the last one).
  static GameSnapshot questionNFinished({
    String? gameId,
    String? currentPlayerId,
    int questionNumber = 1,
    int nQuestions = 5,
    String? questionUid,
    List<String>? questionUids,
    Map<String, PlayerSummary>? players,
    bool isHost = true,
  }) {
    final playerId = currentPlayerId ?? 'player_1';
    final playersMap = players ??
        {
          playerId: PlayerSummary(
            playerId: playerId,
            name: 'Test Player',
            score: 10.0,
            isHost: isHost,
            isActive: true,
            rank: 1,
          ),
        };

    final qUid = questionUid ?? 'question_$questionNumber';
    final qUids =
        questionUids ?? List.generate(nQuestions, (i) => 'question_${i + 1}');

    return GameSnapshot(
      state: GameState.questionNFinished,
      isHost: isHost,
      questionNumber: questionNumber,
      nQuestions: nQuestions,
      durationSeconds: 0,
      players: playersMap,
      isPrivate: false,
      progressAnswered: const <String, bool>{},
      allAnswered: true,
      currentQuestionUid: qUid,
      questionUids: qUids,
    );
  }

  /// Creates a snapshot for the last active question.
  static GameSnapshot questionLast({
    String? gameId,
    String? currentPlayerId,
    int questionNumber = 5,
    int nQuestions = 5,
    String? questionUid,
    List<String>? questionUids,
    int durationSeconds = 15,
    Map<String, PlayerSummary>? players,
    Map<String, bool>? progressAnswered,
    bool allAnswered = false,
    bool isHost = true,
  }) {
    final playerId = currentPlayerId ?? 'player_1';
    final playersMap = players ??
        {
          playerId: PlayerSummary(
            playerId: playerId,
            name: 'Test Player',
            score: 40.0,
            isHost: isHost,
            isActive: true,
            rank: 1,
          ),
        };

    final qUid = questionUid ?? 'question_$questionNumber';
    final qUids =
        questionUids ?? List.generate(nQuestions, (i) => 'question_${i + 1}');

    return GameSnapshot(
      state: GameState.questionLast,
      isHost: isHost,
      questionNumber: questionNumber,
      nQuestions: nQuestions,
      durationSeconds: durationSeconds,
      players: playersMap,
      isPrivate: false,
      progressAnswered: progressAnswered ?? const <String, bool>{},
      allAnswered: allAnswered,
      currentQuestionUid: qUid,
      questionUids: qUids,
    );
  }

  /// Creates a snapshot for the last finished question (before review mode).
  static GameSnapshot questionLastFinished({
    String? gameId,
    String? currentPlayerId,
    int questionNumber = 5,
    int nQuestions = 5,
    String? questionUid,
    List<String>? questionUids,
    Map<String, PlayerSummary>? players,
    bool isHost = true,
  }) {
    final playerId = currentPlayerId ?? 'player_1';
    final playersMap = players ??
        {
          playerId: PlayerSummary(
            playerId: playerId,
            name: 'Test Player',
            score: 50.0,
            isHost: isHost,
            isActive: true,
            rank: 1,
          ),
        };

    final qUid = questionUid ?? 'question_$questionNumber';
    final qUids =
        questionUids ?? List.generate(nQuestions, (i) => 'question_${i + 1}');

    return GameSnapshot(
      state: GameState.questionLastFinished,
      isHost: isHost,
      questionNumber: questionNumber,
      nQuestions: nQuestions,
      durationSeconds: 0,
      players: playersMap,
      isPrivate: false,
      progressAnswered: const <String, bool>{},
      allAnswered: true,
      currentQuestionUid: qUid,
      questionUids: qUids,
    );
  }

  /// Creates a snapshot for a finished game (enters review mode).
  static GameSnapshot gameFinished({
    String? gameId,
    String? currentPlayerId,
    int nQuestions = 5,
    List<String>? questionUids,
    Map<String, PlayerSummary>? players,
    bool isHost = true,
  }) {
    final playerId = currentPlayerId ?? 'player_1';
    final playersMap = players ??
        {
          playerId: PlayerSummary(
            playerId: playerId,
            name: 'Test Player',
            score: 50.0,
            isHost: isHost,
            isActive: true,
            rank: 1,
          ),
        };

    final qUids =
        questionUids ?? List.generate(nQuestions, (i) => 'question_${i + 1}');

    return GameSnapshot(
      state: GameState.gameFinished,
      isHost: isHost,
      questionNumber: nQuestions,
      nQuestions: nQuestions,
      durationSeconds: 0,
      players: playersMap,
      isPrivate: false,
      progressAnswered: const <String, bool>{},
      allAnswered: true,
      currentQuestionUid: null,
      questionUids: qUids,
    );
  }

  /// Creates a snapshot for an aborted game.
  static GameSnapshot gameAborted({
    String? gameId,
    String? currentPlayerId,
    Map<String, PlayerSummary>? players,
    bool isHost = true,
  }) {
    final playerId = currentPlayerId ?? 'player_1';
    final playersMap = players ??
        {
          playerId: PlayerSummary(
            playerId: playerId,
            name: 'Test Player',
            score: 0.0,
            isHost: isHost,
            isActive: false,
            rank: null,
          ),
        };

    return GameSnapshot(
      state: GameState.gameAborted,
      isHost: isHost,
      questionNumber: 0,
      nQuestions: 0,
      durationSeconds: 0,
      players: playersMap,
      isPrivate: false,
      progressAnswered: const <String, bool>{},
      allAnswered: false,
      currentQuestionUid: null,
      questionUids: [],
    );
  }

  /// Creates a multi-player snapshot with 3 players.
  static GameSnapshot multiPlayer({
    String? gameId,
    String? currentPlayerId,
    GameState state = GameState.lobbyReady,
    int questionNumber = 0,
    int nQuestions = 5,
    String? questionUid,
    List<String>? questionUids,
    int durationSeconds = 15,
    Map<String, bool>? progressAnswered,
    bool allAnswered = false,
  }) {
    final playerId = currentPlayerId ?? 'player_1';
    final playersMap = {
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
        isActive: true,
        rank: 3,
      ),
    };

    final qUid =
        questionUid ?? (questionNumber > 0 ? 'question_$questionNumber' : null);
    final qUids =
        questionUids ?? List.generate(nQuestions, (i) => 'question_${i + 1}');

    return GameSnapshot(
      state: state,
      isHost: playerId == 'player_1',
      questionNumber: questionNumber,
      nQuestions: nQuestions,
      durationSeconds: durationSeconds,
      players: playersMap,
      isPrivate: false,
      progressAnswered: progressAnswered ?? const <String, bool>{},
      allAnswered: allAnswered,
      currentQuestionUid: qUid,
      questionUids: qUids,
    );
  }
}
