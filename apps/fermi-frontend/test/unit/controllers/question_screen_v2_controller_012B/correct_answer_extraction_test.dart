import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2_controller.dart';

import 'test_helpers.dart';

/// Unit tests for correct answer extraction in QuestionScreenV2Controller.
///
/// These tests verify that the correct answer is extracted using the current
/// player's ID, not an arbitrary player from the snapshot.
void main() {
  setUpAll(() {
    registerFallbackValue(
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''));
  });

  group('QuestionScreenV2Controller - Correct Answer Extraction', () {
    late MockGameRealtime mockRealtime;
    late QuestionScreenV2Controller controller;

    setUp(() {
      mockRealtime = createMockRealtime();
      controller = createController(mockRealtime);
    });

    tearDown(() {
      controller.dispose();
    });

    test(
        'should use current player correct answer, not first player in snapshot',
        () async {
      // ARRANGE
      // This test simulates the bug scenario where:
      // - Current player (player-1) uses quarts -> correct answer should be 59T quart
      // - Another player (player-2) uses km³ -> correct answer for them is 56K km³
      // The bug was taking .values.first which could be player-2's answer,
      // causing the wrong unit to display.

      const currentPlayerId = testPlayerId; // 'player-1'
      const otherPlayerId = 'player-2';

      // Current player's correct answer (in their unit: quarts)
      const currentPlayerCorrectAnswer = AnswerValue(
        number: 59,
        orderOfMagnitude: 'T', // 59 trillion quarts
        unit: 'quart',
        rawValue: 59e12,
      );

      // Other player's correct answer (in their unit: km³)
      const otherPlayerCorrectAnswer = AnswerValue(
        number: 56,
        orderOfMagnitude: 'K', // 56 thousand km³
        unit: 'km**3',
        rawValue: 56e3,
      );

      // Create game stream
      final gameStream = StreamController<GameSnapshot>();
      when(() => mockRealtime.watchGame(any()))
          .thenAnswer((_) => gameStream.stream);

      // Create revealed question stream
      final questionStream = StreamController<RevealedQuestion>();
      when(() => mockRealtime.revealedQuestion(any(), 0))
          .thenAnswer((_) => questionStream.stream);

      // Create players answers stream with BOTH players' correct answers
      // The key here is that the map contains answers for multiple players
      // and we need to extract the CURRENT player's answer, not just any.
      final answersStream = StreamController<PlayersAnswersSnapshot>();
      when(() => mockRealtime.playersAnswersForQuestion(any(), 0))
          .thenAnswer((_) => answersStream.stream);

      // ACT
      controller.attach();

      // Emit game snapshot
      gameStream.add(const GameSnapshot(
        state: GameState.questionNFinished,
        isHost: false,
        questionNumber: 1,
        nQuestions: testQuestionCount,
        players: {
          currentPlayerId: PlayerSummary(
            playerId: currentPlayerId,
            name: 'Current Player',
            score: 0,
            isHost: false,
            isActive: true,
          ),
          otherPlayerId: PlayerSummary(
            playerId: otherPlayerId,
            name: 'Other Player',
            score: 0,
            isHost: false,
            isActive: true,
          ),
        },
        questionUids: ['q1', 'q2', 'q3'],
      ));

      // Let game snapshot process
      await Future<void>.delayed(Duration.zero);

      // Emit question data
      questionStream.add(const RevealedQuestion(
        text: 'What is the volume of the oceans?',
        tags: ['volume', 'geography'],
        units: ['quart', 'km**3', 'm**3'],
        unitOptions: {'US': 'quart', 'EU': 'm³'},
        unitAbbreviationToId: {'quart': 'quart', 'm³': 'm**3', 'km³': 'km**3'},
        unitIdToAbbreviation: {'quart': 'quart', 'm**3': 'm³', 'km**3': 'km³'},
        category: 'PLANET_EARTH',
      ));

      await Future<void>.delayed(Duration.zero);

      // Emit players answers with correct answers for BOTH players
      // Critical: The 'correct' map has per-player converted answers
      answersStream.add(const PlayersAnswersSnapshot(
        submitted: {
          currentPlayerId: AnswerValue(
            number: 1,
            orderOfMagnitude: '',
            unit: 'quart',
          ),
          otherPlayerId: AnswerValue(
            number: 20,
            orderOfMagnitude: 'K',
            unit: 'km**3',
          ),
        },
        scores: {
          currentPlayerId: 0.0,
          otherPlayerId: 3586.0,
        },
        allAnswered: true,
        // The 'correct' map: playerId -> correct answer in THAT player's unit
        // BUG: .values.first might return otherPlayerCorrectAnswer (56K km³)
        // when it should return currentPlayerCorrectAnswer (59T quart)
        correct: {
          // Intentionally put the OTHER player first to expose the bug
          otherPlayerId: otherPlayerCorrectAnswer,
          currentPlayerId: currentPlayerCorrectAnswer,
        },
        percentiles: {
          currentPlayerId: 0.0,
          otherPlayerId: 0.85,
        },
        convertedAnswers: {},
      ));

      // Let the snapshot process
      await Future<void>.delayed(Duration.zero);

      // ASSERT
      final revealedAnswer = controller.getRevealedAnswer(0);

      // The revealed answer should be in the current player's unit (quart),
      // NOT the other player's unit (km³)
      expect(revealedAnswer, isNotNull,
          reason: 'Revealed answer should not be null after reveal');
      expect(revealedAnswer!.unit, 'quart',
          reason:
              'Correct answer should be in current player unit (quart), not km³');
      expect(revealedAnswer.number, 59,
          reason: 'Correct answer should show 59 (trillion quarts)');
      expect(revealedAnswer.orderOfMagnitude, 'T',
          reason: 'Correct answer should show T (trillion)');

      // Clean up
      await gameStream.close();
      await questionStream.close();
      await answersStream.close();
    });
  });
}
