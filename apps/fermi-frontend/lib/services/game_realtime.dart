import 'dart:async';

import 'package:fermi_frontend/models/answer_value.dart';

/// Narrow realtime adapter interface for backend-driven gameplay.
///
/// This file defines the UI-facing contract only. Provide separate
/// implementations (e.g., Firestore via FlutterFire, and a demo adapter).
///
/// Idempotency expectations:
/// - Commands should be safe to call multiple times; backends enforce
///   permissions and deduplicate.
/// - Streams may replay the latest snapshot on re-subscription; UI
///   controllers guard with idempotent transitions.
abstract class GameRealtime {
  /// Current player's id used to correlate submissions.
  String get currentPlayerId;

  /// Current locale preference ('US' or 'EU') if known.
  String? get currentLocale => null;

  /// Watch the authoritative game document.
  Stream<GameSnapshot> watchGame(String gameId);

  /// Reveal events for a specific question index (0-based in UI).
  Stream<RevealPayload> revealsForQuestion(String gameId, int questionIndex);

  /// Revealed question text and metadata for a specific question index.
  Stream<RevealedQuestion> revealedQuestion(String gameId, int questionIndex);

  /// Players' submitted answers and scores for a question.
  Stream<PlayersAnswersSnapshot> playersAnswersForQuestion(
    String gameId,
    int questionIndex,
  );

  /// Submit or update the local player's answer. Idempotent.
  Future<void> submitAnswer(
    String gameId,
    int questionIndex,
    AnswerValue answer,
  );

  /// Host (or server-side policy) may force a reveal for the active question.
  Future<void> requestForceReveal(String gameId, int questionIndex);

  /// Host-only: request the game to advance. UI advances only after
  /// watchGame emits the new state/question number.
  Future<void> goNext(String gameId);
  Future<void> upvoteQuestion(String questionUid);
  Future<void> deUpvoteQuestion(String questionUid);
  Future<void> downvoteQuestion(String questionUid);
  Future<void> deDownvoteQuestion(String questionUid);
  Future<void> setUserLocale(String locale) async {}
}

/// Thin compatibility shim around existing demo-only GameEvents to align with
/// the new GameRealtime interface for short-term interoperability.
///
/// This should only be used in demo builds and will be removed once the
/// production adapter is wired. Keep in demo namespace in consumers.
abstract class GameEventsCompatibilityShim {
  Stream<RevealPayload> revealsForQuestion(String gameId, int questionIndex);
  Future<void> requestForceReveal(String gameId, int questionIndex);
}

/// Authoritative game snapshot mapped for UI consumption.
class GameSnapshot {
  final GameState state;
  final bool isHost;
  final int questionNumber; // 1-based
  final int nQuestions;
  final int durationSeconds; // for current question (0 if not applicable)
  final Map<String, PlayerSummary> players; // playerId -> summary
  final bool isPrivate; // from game doc 'private'
  final String? joinUrl; // from game doc 'join_url'
  final Map<String, bool> progressAnswered; // current question answered map
  final bool allAnswered;
  final String? currentQuestionUid; // from game doc 'question_uid'
  final List<String> questionUids; // from game doc 'question_uids'

  const GameSnapshot({
    required this.state,
    required this.isHost,
    required this.questionNumber,
    required this.nQuestions,
    required this.durationSeconds,
    required this.players,
    required this.isPrivate,
    this.joinUrl,
    this.progressAnswered = const <String, bool>{},
    this.allAnswered = false,
    this.currentQuestionUid,
    this.questionUids = const <String>[],
  });
}

/// Minimal mirror of backend GameState for UI flow decisions.
enum GameState {
  preLobby,
  lobbyNotReady,
  lobbyReady,
  questionN,
  questionNFinished,
  questionLast,
  questionLastFinished,
  gameFinished,
  gameAborted,
}

class PlayerSummary {
  final String playerId;
  final String? name;
  final String? pictureUrl;
  final double score;
  final bool isHost;
  final bool isActive;
  // Numeric rank as provided by backend. May be null or 0 before first reveal.
  final int? rank;

  const PlayerSummary({
    required this.playerId,
    this.name,
    this.pictureUrl,
    required this.score,
    required this.isHost,
    required this.isActive,
    this.rank,
  });
}

/// Snapshot of players' submissions and scores for a question.
class PlayersAnswersSnapshot {
  final Map<String, AnswerValue> submitted; // playerId -> submitted answer
  final Map<String, double> scores; // playerId -> score
  final bool allAnswered;
  final Map<String, AnswerValue> correct; // playerId -> correct answer
  final Map<String, double> percentiles; // playerId -> percentile (0.0-1.0)

  const PlayersAnswersSnapshot({
    required this.submitted,
    required this.scores,
    required this.allAnswered,
    this.correct = const <String, AnswerValue>{},
    this.percentiles = const <String, double>{},
  });
}

/// Payload delivered on reveal.
class RevealPayload {
  final AnswerValue correct;

  const RevealPayload({required this.correct});
}

/// Minimal payload for revealed question content.
class RevealedQuestion {
  final String text;
  final List<String> tags;
  final List<String> units;
  final Map<String, String> unitOptions;
  // New: mapping between abbreviation and backend unit id for submissions
  final Map<String, String> unitAbbreviationToId;
  final Map<String, String> unitIdToAbbreviation;
  // Number of upvotes for the question (from questions.{uid}.upvotes)
  final int upvotes;
  // Backend category enum name for this question (e.g., PLANET_EARTH)
  final String category;
  // New: current player's vote verdict from questions.{uid}.players_votes[player_id]
  // -1 = downvote, 0 = no vote, 1 = upvote
  final int myVoteVerdict;

  const RevealedQuestion({
    required this.text,
    this.tags = const <String>[],
    this.units = const <String>[],
    this.unitOptions = const <String, String>{},
    this.unitAbbreviationToId = const <String, String>{},
    this.unitIdToAbbreviation = const <String, String>{},
    this.upvotes = 0,
    this.category = '',
    this.myVoteVerdict = 0,
  });
}
