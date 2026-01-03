import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2_controller.dart';

import 'test_helpers.dart';

/// Unit tests for correct answer unit preservation.
///
/// These tests verify that the correct answer displayed on the scale widget
/// uses the per-player correct answer (in user's unit) from players_results,
/// not the global correct answer (in base unit) from answers collection.
void main() {
  setUpAll(() {
    registerFallbackValue(
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''));
  });

  group('QuestionScreenV2Controller - Correct Answer Unit Preservation', () {
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
        'reveal stream should NOT overwrite player-specific correct answer from players_results',
        () async {
      // ARRANGE
      // This test simulates the race condition where:
      // 1. playersAnswersForQuestion emits first with user-specific correct answer (century)
      // 2. revealsForQuestion emits second with global correct answer (seconds)
      // The bug was that _handleReveal would overwrite the correct answer with the global one.

      const currentPlayerId = testPlayerId; // 'player-1'

      // User-specific correct answer (from players_results, in user's unit: century)
      const userSpecificCorrectAnswer = AnswerValue(
        number: 7,
        orderOfMagnitude: 'K', // 7 thousand centuries
        unit: 'century',
        rawValue: 7820.0,
      );

      // Global correct answer (from answers collection, in base unit: seconds)
      const globalCorrectAnswer = AnswerValue(
        number: 25,
        orderOfMagnitude: 'T', // 25 trillion seconds
        unit: 'second',
        rawValue: 24678043200000.0,
      );

      // Create game stream
      final gameStream = StreamController<GameSnapshot>();
      when(() => mockRealtime.watchGame(any()))
          .thenAnswer((_) => gameStream.stream);

      // Create revealed question stream
      final questionStream = StreamController<RevealedQuestion>();
      when(() => mockRealtime.revealedQuestion(any(), 0))
          .thenAnswer((_) => questionStream.stream);

      // Create reveal stream (from answers collection)
      final revealStream = StreamController<RevealPayload>();
      when(() => mockRealtime.revealsForQuestion(any(), 0))
          .thenAnswer((_) => revealStream.stream);

      // Create players answers stream (from players_results collection)
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
        },
        questionUids: ['q1', 'q2', 'q3'],
      ));

      await Future<void>.delayed(Duration.zero);

      // Emit question data with time units
      questionStream.add(const RevealedQuestion(
        text: 'How long did the dinosaurs roam the Earth?',
        tags: ['time', 'history'],
        units: ['century', 'year', 'second'],
        unitOptions: {'Century': 'century', 'Year': 'year', 'Second': 'second'},
        unitAbbreviationToId: {
          'century': 'century',
          'year': 'year',
          'second': 'second'
        },
        unitIdToAbbreviation: {
          'century': 'century',
          'year': 'year',
          'second': 'second'
        },
        category: 'HISTORY',
      ));

      await Future<void>.delayed(Duration.zero);

      // STEP 1: Emit players_results first (with user-specific correct answer in century)
      answersStream.add(const PlayersAnswersSnapshot(
        submitted: {
          currentPlayerId: AnswerValue(
            number: 4,
            orderOfMagnitude: '',
            unit: 'century',
          ),
        },
        scores: {
          currentPlayerId: 136.0,
        },
        allAnswered: true,
        correct: {
          currentPlayerId: userSpecificCorrectAnswer,
        },
        percentiles: {
          currentPlayerId: 0.5,
        },
        convertedAnswers: {},
      ));

      await Future<void>.delayed(Duration.zero);

      // Verify correct answer is set from players_results (century)
      final answerAfterPlayersResults = controller.getRevealedAnswer(0);
      expect(answerAfterPlayersResults, isNotNull,
          reason: 'Correct answer should be set after players_results');
      expect(answerAfterPlayersResults!.unit, 'century',
          reason: 'Correct answer should be in user unit (century)');
      expect(answerAfterPlayersResults.orderOfMagnitude, 'K',
          reason: 'Correct answer should be 7K (7000 centuries)');

      // STEP 2: Emit reveal stream second (with global correct answer in seconds)
      // This simulates the race condition where the reveal stream arrives late
      revealStream.add(const RevealPayload(
        correct: globalCorrectAnswer,
        paragraph: 'Dinosaurs roamed for about 165 million years...',
      ));

      await Future<void>.delayed(Duration.zero);

      // ASSERT: Correct answer should STILL be in century, not overwritten to seconds
      final finalAnswer = controller.getRevealedAnswer(0);
      expect(finalAnswer, isNotNull,
          reason: 'Correct answer should still exist after reveal stream');
      expect(finalAnswer!.unit, 'century',
          reason:
              'Correct answer should STILL be in user unit (century), not overwritten to seconds');
      expect(finalAnswer.orderOfMagnitude, 'K',
          reason:
              'Correct answer should STILL be 7K centuries, not 25T seconds');
      expect(finalAnswer.number, 7,
          reason: 'Correct answer number should be 7, not 25');

      // Clean up
      await gameStream.close();
      await questionStream.close();
      await revealStream.close();
      await answersStream.close();
    });
  });
}
