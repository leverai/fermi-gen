import 'package:flutter_test/flutter_test.dart';
import '../../fixtures/game_snapshots.dart';
import '../../fixtures/question_data.dart';
import '../../fixtures/player_data.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';

/// Sanity tests for fixture factories.
///
/// These tests ensure that all fixture factories can be instantiated
/// without throwing exceptions and that they return valid data structures.
void main() {
  group('GameSnapshotFixtures', () {
    test('should create lobbyNotReady snapshot', () {
      final snapshot = GameSnapshotFixtures.lobbyNotReady();
      expect(snapshot.state, GameState.lobbyNotReady);
      expect(snapshot.players, isNotEmpty);
    });

    test('should create lobbyReady snapshot', () {
      final snapshot = GameSnapshotFixtures.lobbyReady();
      expect(snapshot.state, GameState.lobbyReady);
      expect(snapshot.players, isNotEmpty);
    });

    test('should create questionN snapshot', () {
      final snapshot = GameSnapshotFixtures.questionN();
      expect(snapshot.state, GameState.questionN);
      expect(snapshot.questionNumber, 1);
      expect(snapshot.nQuestions, 5);
    });

    test('should create questionNFinished snapshot', () {
      final snapshot = GameSnapshotFixtures.questionNFinished();
      expect(snapshot.state, GameState.questionNFinished);
      expect(snapshot.allAnswered, true);
    });

    test('should create questionLast snapshot', () {
      final snapshot = GameSnapshotFixtures.questionLast();
      expect(snapshot.state, GameState.questionLast);
      expect(snapshot.questionNumber, 5);
    });

    test('should create questionLastFinished snapshot', () {
      final snapshot = GameSnapshotFixtures.questionLastFinished();
      expect(snapshot.state, GameState.questionLastFinished);
      expect(snapshot.allAnswered, true);
    });

    test('should create gameFinished snapshot', () {
      final snapshot = GameSnapshotFixtures.gameFinished();
      expect(snapshot.state, GameState.gameFinished);
    });

    test('should create gameAborted snapshot', () {
      final snapshot = GameSnapshotFixtures.gameAborted();
      expect(snapshot.state, GameState.gameAborted);
    });

    test('should create multiPlayer snapshot', () {
      final snapshot = GameSnapshotFixtures.multiPlayer();
      expect(snapshot.players.length, 3);
      expect(snapshot.players['player_1']?.isHost, true);
    });
  });

  group('QuestionDataFixtures', () {
    test('should create question1', () {
      final question = QuestionDataFixtures.question1();
      expect(question.text, QuestionDataFixtures.sampleQuestion1);
      expect(question.tags, isNotEmpty);
      expect(question.units, isNotEmpty);
    });

    test('should create question2', () {
      final question = QuestionDataFixtures.question2();
      expect(question.text, QuestionDataFixtures.sampleQuestion2);
    });

    test('should create question3', () {
      final question = QuestionDataFixtures.question3();
      expect(question.text, QuestionDataFixtures.sampleQuestion3);
    });

    test('should create question4', () {
      final question = QuestionDataFixtures.question4();
      expect(question.text, QuestionDataFixtures.sampleQuestion4);
    });

    test('should create question5', () {
      final question = QuestionDataFixtures.question5();
      expect(question.text, QuestionDataFixtures.sampleQuestion5);
    });

    test('should create unitless question', () {
      final question = QuestionDataFixtures.unitlessQuestion();
      expect(question.units, isEmpty);
    });

    test('should create correct answers', () {
      final answer1 = QuestionDataFixtures.correctAnswer1();
      expect(answer1.number, 8);
      expect(answer1.orderOfMagnitude, 'M');

      final answer2 = QuestionDataFixtures.correctAnswer2();
      expect(answer2.number, 6);
    });

    test('should create question UIDs', () {
      final uids = QuestionDataFixtures.questionUids(count: 3);
      expect(uids.length, 3);
      expect(uids[0], 'question_1');
    });

    test('should create reveal payload', () {
      final answer = QuestionDataFixtures.correctAnswer1();
      final payload = QuestionDataFixtures.revealPayload(answer);
      expect(payload.correct, answer);
    });

    test('should support US and EU locales', () {
      final usQuestion = QuestionDataFixtures.question1(locale: 'US');
      final euQuestion = QuestionDataFixtures.question1(locale: 'EU');
      expect(usQuestion.unitOptions, isNotEmpty);
      expect(euQuestion.unitOptions, isNotEmpty);
    });
  });

  group('PlayerDataFixtures', () {
    test('should create single player', () {
      final player = PlayerDataFixtures.singlePlayer();
      expect(player.isHost, true);
      expect(player.isActive, true);
    });

    test('should create player', () {
      final player = PlayerDataFixtures.player(
        playerId: 'test_player',
        name: 'Test',
      );
      expect(player.playerId, 'test_player');
      expect(player.name, 'Test');
    });

    test('should create three players', () {
      final players = PlayerDataFixtures.threePlayers();
      expect(players.length, 3);
      expect(players['player_1']?.isHost, true);
      expect(players['player_2']?.isHost, false);
    });

    test('should create four players with ties', () {
      final players = PlayerDataFixtures.fourPlayersWithTies();
      expect(players.length, 4);
      expect(players['player_1']?.rank, 1);
      expect(players['player_2']?.rank, 1); // Tie
    });

    test('should create players with inactive', () {
      final players = PlayerDataFixtures.playersWithInactive();
      expect(players['player_3']?.isActive, false);
    });

    test('should create player states', () {
      final waiting = PlayerDataFixtures.waitingPlayerState();
      expect(waiting.status, PlayerStatus.waiting);

      final ready = PlayerDataFixtures.readyPlayerState();
      expect(ready.status, PlayerStatus.ready);

      final answer = PlayerDataFixtures.answerPlayerState();
      expect(answer.status, PlayerStatus.answer);
    });

    test('should create submitted answers', () {
      final answers = PlayerDataFixtures.submittedAnswers();
      expect(answers.length, 3);
      expect(answers.values.first.number, 8);
    });

    test('should create player scores', () {
      final scores = PlayerDataFixtures.playerScores();
      expect(scores.length, 3);
      expect(scores.values.first, 10.0);
    });

    test('should create cumulative scores', () {
      final scores = PlayerDataFixtures.cumulativeScores();
      expect(scores.length, 3);
      expect(scores.values.first, 20);
    });

    test('should create player percentiles', () {
      final percentiles = PlayerDataFixtures.playerPercentiles();
      expect(percentiles.length, 3);
      expect(percentiles.values.first, 0.95);
    });

    test('should create progress answered map', () {
      final progress = PlayerDataFixtures.progressAnswered();
      expect(progress.length, 3);
      expect(progress.values.first, true);
    });

    test('should create all players answered map', () {
      final progress = PlayerDataFixtures.allPlayersAnswered();
      expect(progress.values.every((v) => v == true), true);
    });
  });
}
