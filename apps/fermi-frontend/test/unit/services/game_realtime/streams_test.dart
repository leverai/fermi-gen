import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/services/firestore_game_realtime.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import '../../../helpers/mock_factories.dart';
import 'test_helpers.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreGameRealtime realtime;
  const String gameId = 'test-game-123';
  const String currentPlayerId = 'player-1';
  const String hostPlayerId = 'player-1';

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    realtime = createTestRealtime(
      firestore: fakeFirestore,
      currentPlayerId: currentPlayerId,
    );
  });

  group('Stream Behavior', () {
    test('should emit snapshots on document changes', () async {
      // ARRANGE
      final stream = realtime.watchGame(gameId);
      final snapshots = <GameSnapshot>[];

      final subscription = stream.listen((snapshot) {
        snapshots.add(snapshot);
      });

      // ACT - Initial state
      await fakeFirestore.collection('games').doc(gameId).set({
        'state': 2,
        'host': hostPlayerId,
        'n_questions': 5,
        'question_number': 0,
        'players': {},
        'progress': {'answered': {}, 'all_answered': false},
      });

      await Future.delayed(const Duration(milliseconds: 200));

      // ACT - Change state
      await fakeFirestore.collection('games').doc(gameId).update({
        'state': 3,
        'question_number': 1,
      });

      await Future.delayed(const Duration(milliseconds: 200));

      // ASSERT
      expect(snapshots.length, greaterThanOrEqualTo(2),
          reason: 'Expected at least 2 snapshots, got ${snapshots.length}');
      // First snapshot might be preLobby (before document exists), then lobbyReady
      final lobbyReadySnapshot = snapshots.firstWhere(
        (s) => s.state == GameState.lobbyReady,
        orElse: () => snapshots.first,
      );
      expect(lobbyReadySnapshot.state, GameState.lobbyReady);
      expect(snapshots.last.state, GameState.questionN);
      expect(snapshots.last.questionNumber, 1);

      await subscription.cancel();
    });

    test('should emit question on reveal', () async {
      // ARRANGE
      await fakeFirestore.collection('games').doc(gameId).set({
        'state': 3,
        'host': hostPlayerId,
        'n_questions': 5,
        'question_number': 1,
        'question_uid': 'q1',
        'question_uids': ['q1'],
        'players': {},
        'progress': {'answered': {}, 'all_answered': false},
      });

      // ACT
      final stream = realtime.revealedQuestion(gameId, 0);
      final questions = <RevealedQuestion>[];

      final subscription = stream.listen((question) {
        questions.add(question);
      });

      await fakeFirestore
          .collection('games')
          .doc(gameId)
          .collection('questions')
          .doc('q1')
          .set({
        'text': 'What is 2+2?',
        'revealed': true,
        'tags': ['math'],
        'units': {},
        'upvotes': 5,
        'category': 'MATH',
        'players_votes': {},
      });

      await Future.delayed(const Duration(milliseconds: 100));

      // ASSERT
      expect(questions, isNotEmpty);
      expect(questions.last.text, 'What is 2+2?');
      expect(questions.last.tags, ['math']);
      expect(questions.last.upvotes, 5);

      await subscription.cancel();
    });

    test('should emit reveal payload when revealed', () async {
      // ARRANGE
      await fakeFirestore.collection('games').doc(gameId).set({
        'state': 3,
        'host': hostPlayerId,
        'n_questions': 5,
        'question_number': 1,
        'question_uid': 'q1',
        'question_uids': ['q1'],
        'players': {},
        'progress': {'answered': {}, 'all_answered': false},
      });

      // ACT
      final stream = realtime.revealsForQuestion(gameId, 0);
      final payloads = <RevealPayload>[];

      final subscription = stream.listen((payload) {
        payloads.add(payload);
      });

      await fakeFirestore
          .collection('games')
          .doc(gameId)
          .collection('answers')
          .doc('q1')
          .set({
        'number': 1000.0,
        'unit': 'm',
        'revealed': true,
      });

      await Future.delayed(const Duration(milliseconds: 100));

      // ASSERT
      expect(payloads, isNotEmpty);
      expect(payloads.last.correct.number, 1);
      expect(payloads.last.correct.orderOfMagnitude, 'K');
      expect(payloads.last.correct.unit, 'm');

      await subscription.cancel();
    });

    test('should emit answers when all players answered', () async {
      // ARRANGE
      await fakeFirestore.collection('games').doc(gameId).set({
        'state': 3,
        'host': hostPlayerId,
        'n_questions': 5,
        'question_number': 1,
        'question_uid': 'q1',
        'question_uids': ['q1'],
        'players': {},
        'progress': {'answered': {}, 'all_answered': false},
      });

      // ACT
      final stream = realtime.playersAnswersForQuestion(gameId, 0);
      final snapshots = <PlayersAnswersSnapshot>[];

      final subscription = stream.listen((snapshot) {
        snapshots.add(snapshot);
      });

      await fakeFirestore
          .collection('games')
          .doc(gameId)
          .collection('players_results')
          .doc('q1')
          .set({
        'revealed': true,
        'players_results': {
          'player-1': {
            'answer': {'number': 100.0, 'unit': 'm'},
            'score': 0.8,
            'correct_answer': {'number': 100.0, 'unit': 'm'},
          },
          'player-2': {
            'answer': {'number': 200.0, 'unit': 'm'},
            'score': 0.5,
            'correct_answer': {'number': 100.0, 'unit': 'm'},
          },
        },
      });

      await Future.delayed(const Duration(milliseconds: 100));

      // ASSERT
      expect(snapshots, isNotEmpty);
      expect(snapshots.last.submitted, hasLength(2));
      expect(snapshots.last.scores['player-1'], 0.8);
      expect(snapshots.last.scores['player-2'], 0.5);
      expect(snapshots.last.correct['player-1']?.number, 100);

      await subscription.cancel();
    });
  });
}
