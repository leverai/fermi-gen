import 'dart:async';

import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/screens/question_v2/helpers/diagnostics.dart';

/// Small helper that wires per-question realtime streams.
/// No guards or state transitions here; delegate to controllers.
class QuestionPaneBindings {
  final GameRealtime realtime;
  final String gameId;
  final int index;

  StreamSubscription<RevealPayload>? _revealSub;
  StreamSubscription<PlayersAnswersSnapshot>? _playersAnswersSub;
  StreamSubscription<RevealedQuestion>? _questionSub;

  QuestionPaneBindings({
    required this.realtime,
    required this.gameId,
    required this.index,
  });

  void listen({
    required void Function(AnswerValue correct) onReveal,
    required void Function(PlayersAnswersSnapshot snapshot) onPlayersAnswers,
    void Function(RevealedQuestion q)? onQuestion,
    void Function(Object error, StackTrace st)? onError,
  }) {
    _revealSub?.cancel();
    _playersAnswersSub?.cancel();
    _questionSub?.cancel();

    // Debug: confirm bindings attached
    qlog('[bindings] attach gameId=$gameId index=$index');

    _revealSub =
        realtime.revealsForQuestion(gameId, index).listen((RevealPayload p) {
      qlog('[bindings] reveal onData index=$index');
      onReveal(p.correct);
    }, onError: (Object e, StackTrace st) {
      qlog('[bindings] reveal onError index=$index e=$e');
      if (onError != null) onError(e, st);
    });

    _playersAnswersSub =
        realtime.playersAnswersForQuestion(gameId, index).listen((snapshot) {
      qlog(
          '[bindings] players_results onData index=$index submitted=${snapshot.submitted.length}');
      onPlayersAnswers(snapshot);
    }, onError: (Object e, StackTrace st) {
      qlog('[bindings] players_results onError index=$index e=$e');
      if (onError != null) onError(e, st);
    });

    if (onQuestion != null) {
      // Revealed question text and metadata
      _questionSub = realtime.revealedQuestion(gameId, index).listen((q) {
        qlog('[bindings] question onData index=$index');
        onQuestion(q);
      }, onError: (Object e, StackTrace st) {
        qlog('[bindings] question onError index=$index e=$e');
        if (onError != null) onError(e, st);
      });
    }
  }

  void dispose() {
    _revealSub?.cancel();
    _revealSub = null;
    _playersAnswersSub?.cancel();
    _playersAnswersSub = null;
    _questionSub?.cancel();
    _questionSub = null;
  }
}
