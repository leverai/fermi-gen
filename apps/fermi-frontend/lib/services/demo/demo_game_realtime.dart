import 'dart:async';

import 'package:fermi_frontend/services/demo/demo_synth.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/models/answer_value.dart';

/// Demo implementation of GameRealtime for local showcases.
///
/// Emits deterministic snapshots and reveal payloads derived from local input.
class DemoGameRealtime implements GameRealtime {
  DemoGameRealtime({required this.isHost}) {
    _latest = GameSnapshot(
      state: GameState.questionN,
      isHost: isHost,
      questionNumber: 1,
      nQuestions: 3,
      durationSeconds: 10,
      players: const {
        'host': PlayerSummary(
          playerId: 'host',
          name: 'Host',
          pictureUrl: null,
          score: 0,
          isHost: true,
          isActive: true,
          rank: 1,
        ),
        'p2': PlayerSummary(
          playerId: 'p2',
          name: 'P2',
          pictureUrl: null,
          score: 0,
          isHost: false,
          isActive: true,
          rank: 2,
        ),
        'me': PlayerSummary(
          playerId: 'me',
          name: 'You',
          pictureUrl: null,
          score: 0,
          isHost: false,
          isActive: true,
          rank: 3,
        ),
      },
      isPrivate: false,
    );
  }

  final bool isHost;

  @override
  String get currentPlayerId => 'me';

  String _locale = 'US';

  @override
  String? get currentLocale => _locale;

  final StreamController<GameSnapshot> _game =
      StreamController<GameSnapshot>.broadcast();

  final Map<int, StreamController<RevealPayload>> _revealByQuestion = {};
  final Map<int, StreamController<PlayersAnswersSnapshot>> _playersByQuestion =
      {};
  final Map<int, StreamController<RevealedQuestion>> _questionByIndex = {};

  late GameSnapshot _latest;

  @override
  Stream<GameSnapshot> watchGame(String gameId) {
    // Emit latest on subscribe
    Future.microtask(() => _game.add(_latest));
    return _game.stream;
  }

  @override
  Stream<RevealPayload> revealsForQuestion(String gameId, int questionIndex) {
    return (_revealByQuestion[questionIndex] ??=
            StreamController<RevealPayload>.broadcast())
        .stream;
  }

  @override
  Stream<RevealedQuestion> revealedQuestion(String gameId, int questionIndex) {
    return (_questionByIndex[questionIndex] ??=
            StreamController<RevealedQuestion>.broadcast())
        .stream;
  }

  @override
  Stream<PlayersAnswersSnapshot> playersAnswersForQuestion(
    String gameId,
    int questionIndex,
  ) {
    return (_playersByQuestion[questionIndex] ??=
            StreamController<PlayersAnswersSnapshot>.broadcast())
        .stream;
  }

  @override
  Future<void> submitAnswer(
    String gameId,
    int questionIndex,
    AnswerValue answer,
  ) async {
    // Immediately reflect local submission and synthetic others.
    final localIdx = isHost ? 0 : 2;
    final submitted = <String, AnswerValue>{
      'host': synthesizeSubmittedAnswer(answer, 0, localIdx),
      'p2': synthesizeSubmittedAnswer(answer, 1, localIdx),
      'me': synthesizeSubmittedAnswer(answer, 2, localIdx),
    };
    final scores = <String, double>{
      'host': computeScoreIncrement(questionIndex, 0).toDouble(),
      'p2': computeScoreIncrement(questionIndex, 1).toDouble(),
      'me': computeScoreIncrement(questionIndex, 2).toDouble(),
    };
    _playersByQuestion[questionIndex]?.add(
      PlayersAnswersSnapshot(
        submitted: submitted,
        scores: scores,
        allAnswered: true,
      ),
    );
  }

  @override
  Future<void> requestForceReveal(String gameId, int questionIndex) async {
    // Emit a deterministic reveal shortly after.
    await Future.delayed(const Duration(milliseconds: 400));
    _revealByQuestion[questionIndex]?.add(
      const RevealPayload(
        correct: AnswerValue(number: 500, orderOfMagnitude: '', unit: ''),
      ),
    );
    // Also emit a simple revealed question text for demos
    _questionByIndex[questionIndex]?.add(
      const RevealedQuestion(
        text: 'Demo question text (revealed)',
        tags: <String>['demo'],
        units: <String>[''],
      ),
    );
  }

  @override
  Future<void> goNext(String gameId) async {
    // Advance locally; consumers should still mirror server in production.
    final next = (_latest.questionNumber + 1).clamp(1, _latest.nQuestions);
    _latest = GameSnapshot(
      state: next == _latest.nQuestions
          ? GameState.questionLast
          : GameState.questionN,
      isHost: isHost,
      questionNumber: next,
      nQuestions: _latest.nQuestions,
      durationSeconds: _latest.durationSeconds,
      players: _latest.players,
      isPrivate: false,
    );
    _game.add(_latest);
  }

  @override
  Future<void> upvoteQuestion(String questionUid) async {
    // Demo: no-op
  }

  @override
  Future<void> deUpvoteQuestion(String questionUid) async {
    // Demo: no-op
  }

  @override
  Future<void> downvoteQuestion(String questionUid) async {
    // Demo: no-op
  }

  @override
  Future<void> deDownvoteQuestion(String questionUid) async {
    // Demo: no-op
  }

  @override
  Future<void> setUserLocale(String locale) async {
    _locale = locale.toUpperCase();
  }
}
