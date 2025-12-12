import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/models/game_config.dart';
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
  const String otherPlayerId = 'player-2';

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

  group('FirestoreGameRealtime Implementation', () {
    test('should map game document to GameSnapshot', () async {
      // ARRANGE
      await fakeFirestore.collection('games').doc(gameId).set({
        'state': 3, // questionN
        'host': hostPlayerId,
        'n_questions': 5,
        'question_number': 1,
        'question_uid': 'q1',
        'question_uids': ['q1', 'q2', 'q3', 'q4', 'q5'],
        'question_duration_s': 15,
        'private': false,
        'players': {
          currentPlayerId: {
            'name': 'Player 1',
            'picture': null,
            'score': 10.0,
            'is_host': true,
            'is_active': true,
            'rank': 1,
          },
        },
        'progress': {
          'answered': {currentPlayerId: false},
          'all_answered': false,
        },
      });

      // ACT
      final stream = realtime.watchGame(gameId);
      final snapshot = await stream.first;

      // ASSERT
      expect(snapshot.state, GameState.questionN);
      expect(snapshot.isHost, true);
      expect(snapshot.questionNumber, 1);
      expect(snapshot.nQuestions, 5);
      expect(snapshot.durationSeconds, 15);
      expect(snapshot.isPrivate, false);
      expect(snapshot.players, hasLength(1));
      expect(snapshot.players[currentPlayerId]?.name, 'Player 1');
      expect(snapshot.players[currentPlayerId]?.score, 10.0);
      expect(snapshot.players[currentPlayerId]?.isHost, true);
      expect(snapshot.currentQuestionUid, 'q1');
      expect(snapshot.questionUids, ['q1', 'q2', 'q3', 'q4', 'q5']);
    });

    test('should parse game state enum correctly', () async {
      // ARRANGE & ACT & ASSERT
      final states = [
        (0, GameState.preLobby),
        (1, GameState.lobbyNotReady),
        (2, GameState.lobbyReady),
        (3, GameState.questionN),
        (4, GameState.questionNFinished),
        (5, GameState.questionLast),
        (6, GameState.questionLastFinished),
        (8, GameState.gameFinished),
        (9, GameState.gameAborted),
      ];

      for (final (code, expectedState) in states) {
        await fakeFirestore.collection('games').doc('game-$code').set({
          'state': code,
          'host': hostPlayerId,
          'n_questions': 5,
          'question_number': 0,
          'players': {},
          'progress': {'answered': {}, 'all_answered': false},
        });

        final stream = realtime.watchGame('game-$code');
        final snapshot = await stream.first;
        expect(snapshot.state, expectedState, reason: 'State code $code');
      }
    });

    test('should extract player summaries', () async {
      // ARRANGE
      await fakeFirestore.collection('games').doc(gameId).set({
        'state': 2, // lobbyReady
        'host': hostPlayerId,
        'n_questions': 5,
        'question_number': 0,
        'players': {
          'player-1': {
            'name': 'Alice',
            'picture': 'https://example.com/alice.jpg',
            'score': 20.0,
            'is_host': true,
            'is_active': true,
            'rank': 1,
          },
          'player-2': {
            'name': 'Bob',
            'picture': null,
            'score': 15.0,
            'is_host': false,
            'is_active': true,
            'rank': 2,
          },
        },
        'progress': {'answered': {}, 'all_answered': false},
      });

      // ACT
      final stream = realtime.watchGame(gameId);
      final snapshot = await stream.first;

      // ASSERT
      expect(snapshot.players, hasLength(2));
      expect(snapshot.players['player-1']?.name, 'Alice');
      expect(snapshot.players['player-1']?.pictureUrl,
          'https://example.com/alice.jpg');
      expect(snapshot.players['player-1']?.score, 20.0);
      expect(snapshot.players['player-1']?.isHost, true);
      expect(snapshot.players['player-1']?.rank, 1);
      expect(snapshot.players['player-2']?.name, 'Bob');
      expect(snapshot.players['player-2']?.pictureUrl, null);
      expect(snapshot.players['player-2']?.score, 15.0);
      expect(snapshot.players['player-2']?.isHost, false);
      expect(snapshot.players['player-2']?.rank, 2);
    });

    test('should detect host status', () async {
      // ARRANGE - current player is host
      await fakeFirestore.collection('games').doc(gameId).set({
        'state': 2,
        'host': currentPlayerId,
        'n_questions': 5,
        'question_number': 0,
        'players': {},
        'progress': {'answered': {}, 'all_answered': false},
      });

      // ACT
      final stream = realtime.watchGame(gameId);
      final snapshot = await stream.first;

      // ASSERT
      expect(snapshot.isHost, true);

      // ARRANGE - current player is not host
      final nonHostRealtime = createTestRealtime(
        firestore: fakeFirestore,
        currentPlayerId: otherPlayerId,
      );
      await fakeFirestore.collection('games').doc('game-2').set({
        'state': 2,
        'host': currentPlayerId,
        'n_questions': 5,
        'question_number': 0,
        'players': {},
        'progress': {'answered': {}, 'all_answered': false},
      });

      // ACT
      final stream2 = nonHostRealtime.watchGame('game-2');
      final snapshot2 = await stream2.first;

      // ASSERT
      expect(snapshot2.isHost, false);
    });

    test('should calculate question number from UID', () async {
      // ARRANGE
      await fakeFirestore.collection('games').doc(gameId).set({
        'state': 3,
        'host': hostPlayerId,
        'n_questions': 5,
        'question_number': 0, // Missing, should derive from UID
        'question_uid': 'q3',
        'question_uids': ['q1', 'q2', 'q3', 'q4', 'q5'],
        'players': {},
        'progress': {'answered': {}, 'all_answered': false},
      });

      // ACT
      final stream = realtime.watchGame(gameId);
      final snapshot = await stream.first;

      // ASSERT
      expect(snapshot.questionNumber, 3); // q3 is at index 2, so 1-based = 3
    });

    test('should extract duration from game doc', () async {
      // ARRANGE
      await fakeFirestore.collection('games').doc(gameId).set({
        'state': 3,
        'host': hostPlayerId,
        'n_questions': 5,
        'question_number': 1,
        'question_duration_s': 30,
        'players': {},
        'progress': {'answered': {}, 'all_answered': false},
      });

      // ACT
      final stream = realtime.watchGame(gameId);
      final snapshot = await stream.first;

      // ASSERT
      expect(snapshot.durationSeconds, 30);
    });

    test('should extract progress answered map', () async {
      // ARRANGE
      await fakeFirestore.collection('games').doc(gameId).set({
        'state': 3,
        'host': hostPlayerId,
        'n_questions': 5,
        'question_number': 1,
        'players': {},
        'progress': {
          'answered': {
            'player-1': true,
            'player-2': false,
          },
          'all_answered': false,
        },
      });

      // ACT
      final stream = realtime.watchGame(gameId);
      final snapshot = await stream.first;

      // ASSERT
      expect(snapshot.progressAnswered['player-1'], true);
      expect(snapshot.progressAnswered['player-2'], false);
      expect(snapshot.allAnswered, false);
    });

    test('should handle missing game document', () async {
      // ACT
      final stream = realtime.watchGame('non-existent-game');
      final snapshot = await stream.first;

      // ASSERT
      expect(snapshot.state, GameState.preLobby);
      expect(snapshot.isHost, false);
      expect(snapshot.questionNumber, 0);
      expect(snapshot.nQuestions, 0);
      expect(snapshot.players, isEmpty);
    });

    test('should map units by locale', () async {
      // ARRANGE
      final usRealtime = FirestoreGameRealtime(
        currentPlayerId: currentPlayerId,
        firestore: fakeFirestore,
        resolveLocale: () => 'US',
        gameConfig: const GameConfig(
          categories: [],
          difficulties: [],
        ),
      );

      await fakeFirestore
          .collection('games')
          .doc(gameId)
          .collection('questions')
          .doc('q1')
          .set({
        'text': 'Test question',
        'revealed': true,
        'units': {
          'US': [
            {'id': 'unit1', 'name': 'Miles', 'abbreviation': 'mi'},
            {'id': 'unit2', 'name': 'Feet', 'abbreviation': 'ft'},
          ],
          'EU': [
            {'id': 'unit3', 'name': 'Kilometers', 'abbreviation': 'km'},
          ],
        },
      });

      // ACT
      final stream = usRealtime.revealedQuestion(gameId, 0);
      final question = await stream.first;

      // ASSERT
      expect(question.units, ['mi', 'ft']);
      expect(question.unitOptions['Miles'], 'mi');
      expect(question.unitOptions['Feet'], 'ft');
      expect(question.unitAbbreviationToId['mi'], 'unit1');
      expect(question.unitAbbreviationToId['ft'], 'unit2');
    });

    test('should build unit abbreviation to ID maps', () async {
      // ARRANGE
      final usRealtime = FirestoreGameRealtime(
        currentPlayerId: currentPlayerId,
        firestore: fakeFirestore,
        resolveLocale: () => 'US',
        gameConfig: const GameConfig(
          categories: [],
          difficulties: [],
        ),
      );

      await fakeFirestore
          .collection('games')
          .doc(gameId)
          .collection('questions')
          .doc('q1')
          .set({
        'text': 'Test question',
        'revealed': true,
        'units': {
          'US': [
            {'id': 'unit1', 'name': 'Miles', 'abbreviation': 'mi'},
          ],
        },
      });

      // ACT
      final stream = usRealtime.revealedQuestion(gameId, 0);
      final question = await stream.first;

      // ASSERT
      expect(question.unitAbbreviationToId['mi'], 'unit1');
      expect(question.unitIdToAbbreviation['unit1'], 'mi');
    });

    test('should convert unit IDs to abbreviations in converted answers',
        () async {
      // ARRANGE
      final usRealtime = FirestoreGameRealtime(
        currentPlayerId: currentPlayerId,
        firestore: fakeFirestore,
        resolveLocale: () => 'US',
        gameConfig: const GameConfig(
          categories: [],
          difficulties: [],
        ),
      );

      // Set up question with units (to populate the cache)
      await fakeFirestore
          .collection('games')
          .doc(gameId)
          .collection('questions')
          .doc('q1')
          .set({
        'text': 'Test question',
        'revealed': true,
        'units': {
          'US': [
            {'id': 'foot', 'name': 'Foot', 'abbreviation': 'ft'},
          ],
          'EU': [
            {'id': 'meter', 'name': 'Meter', 'abbreviation': 'm'},
          ],
        },
      });

      // Set up players_results with converted_answers containing unit IDs
      await fakeFirestore
          .collection('games')
          .doc(gameId)
          .collection('players_results')
          .doc('q1')
          .set({
        'revealed': true,
        'players_results': {
          'player-1': {
            'answer': {'number': 500, 'unit': 'foot'},
            'score': 100,
            'converted_answers': {
              'player-2': {
                'number': 152.4,
                'unit': 'meter' // Backend returns unit ID, not abbreviation
              },
            },
          },
          'player-2': {
            'answer': {'number': 150, 'unit': 'meter'},
            'score': 95,
            'converted_answers': {
              'player-1': {
                'number': 492.1,
                'unit': 'foot' // Backend returns unit ID, not abbreviation
              },
            },
          },
        },
      });

      // ACT
      // First, watch the question to populate the cache
      final questionStream = usRealtime.revealedQuestion(gameId, 0);
      await questionStream.first;

      // Then, watch players answers
      final answersStream = usRealtime.playersAnswersForQuestion(gameId, 0);
      final snapshot = await answersStream.first;

      // ASSERT
      // Player 1's answer should use abbreviation
      expect(snapshot.submitted['player-1']?.unit, 'ft');

      // Player 1's view of Player 2's converted answer should use abbreviation
      final player1ConvertedAnswers = snapshot.convertedAnswers['player-1'];
      expect(player1ConvertedAnswers, isNotNull);
      expect(player1ConvertedAnswers!['player-2']?.unit, 'm',
          reason:
              'Player 1 (US) should see Player 2\'s answer with abbreviation "m" not ID "meter"');

      // Player 2's answer should use abbreviation
      expect(snapshot.submitted['player-2']?.unit, 'm');

      // Player 2's view of Player 1's converted answer should use abbreviation
      final player2ConvertedAnswers = snapshot.convertedAnswers['player-2'];
      expect(player2ConvertedAnswers, isNotNull);
      expect(player2ConvertedAnswers!['player-1']?.unit, 'ft',
          reason:
              'Player 2 (EU) should see Player 1\'s answer with abbreviation "ft" not ID "foot"');
    });
  });
}
