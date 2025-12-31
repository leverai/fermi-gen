import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2_controller.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
        const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''));
  });

  group('QuestionScreenV2Controller - Answer Input', () {
    late MockGameRealtime mockRealtime;
    late QuestionScreenV2Controller controller;

    setUp(() {
      mockRealtime = createMockRealtime();
      controller = createController(mockRealtime);
    });

    tearDown(() {
      controller.dispose();
    });

    test('should update current answer on change', () {
      // Arrange
      controller.attach();
      const newAnswer = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm',
      );

      // Act
      controller.onAnswerChanged(newAnswer);

      // Assert
      expect(controller.currentAnswer, equals(newAnswer));
    });

    test('should convert UI answer to submission format', () async {
      // Arrange
      final questionStream = StreamController<RevealedQuestion>();
      when(() => mockRealtime.revealedQuestion(testGameId, 0))
          .thenAnswer((_) => questionStream.stream);

      controller.attach();

      // Emit question to populate state
      questionStream.add(const RevealedQuestion(
        text: 'Test question',
        tags: [],
        units: ['m', 'km'],
        unitOptions: {'Meter': 'm', 'Kilometer': 'km'},
        unitAbbreviationToId: {'m': 'meter-id', 'km': 'kilometer-id'},
        unitIdToAbbreviation: {'meter-id': 'm', 'kilometer-id': 'km'},
        category: 'test',
        upvotes: 0,
        myVoteVerdict: 0,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Set answer with abbreviation
      controller.onAnswerChanged(const AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm', // abbreviation
      ));

      // Act
      await controller.submitAnswer();

      // Assert
      verify(() => mockRealtime.submitAnswer(
            testGameId,
            0,
            const AnswerValue(
              number: 42,
              orderOfMagnitude: 'K',
              unit: 'meter-id', // should be converted to ID
            ),
          )).called(1);

      questionStream.close();
    });

    test('should handle unit abbreviation to ID mapping', () async {
      // Arrange
      final questionStream = StreamController<RevealedQuestion>();
      when(() => mockRealtime.revealedQuestion(testGameId, 0))
          .thenAnswer((_) => questionStream.stream);

      controller.attach();

      questionStream.add(const RevealedQuestion(
        text: 'Test question',
        tags: [],
        units: ['m', 'km'],
        unitOptions: {'Meter': 'm', 'Kilometer': 'km'},
        unitAbbreviationToId: {'m': 'meter-id', 'km': 'kilometer-id'},
        unitIdToAbbreviation: {'meter-id': 'm', 'kilometer-id': 'km'},
        category: 'test',
        upvotes: 0,
        myVoteVerdict: 0,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      controller.onAnswerChanged(const AnswerValue(
        number: 100,
        orderOfMagnitude: '',
        unit: 'km',
      ));

      // Act
      await controller.submitAnswer();

      // Assert
      verify(() => mockRealtime.submitAnswer(
            testGameId,
            0,
            const AnswerValue(
              number: 100,
              orderOfMagnitude: '',
              unit: 'kilometer-id',
            ),
          )).called(1);

      questionStream.close();
    });

    test('should submit unitless answer as null', () async {
      // Arrange
      final questionStream = StreamController<RevealedQuestion>();
      when(() => mockRealtime.revealedQuestion(testGameId, 0))
          .thenAnswer((_) => questionStream.stream);

      controller.attach();

      questionStream.add(const RevealedQuestion(
        text: 'Test question',
        tags: [],
        units: [],
        unitOptions: {},
        unitAbbreviationToId: {},
        unitIdToAbbreviation: {},
        category: 'test',
        upvotes: 0,
        myVoteVerdict: 0,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      controller.onAnswerChanged(const AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: '', // no unit
      ));

      // Act
      await controller.submitAnswer();

      // Assert
      verify(() => mockRealtime.submitAnswer(
            testGameId,
            0,
            const AnswerValue(
              number: 42,
              orderOfMagnitude: 'K',
              unit: '', // should remain empty
            ),
          )).called(1);

      questionStream.close();
    });

    test('should prevent duplicate submissions', () async {
      // Arrange
      final questionStream = StreamController<RevealedQuestion>();
      when(() => mockRealtime.revealedQuestion(testGameId, 0))
          .thenAnswer((_) => questionStream.stream);

      controller.attach();

      questionStream.add(const RevealedQuestion(
        text: 'Test question',
        tags: [],
        units: ['m'],
        unitOptions: {'Meter': 'm'},
        unitAbbreviationToId: {'m': 'meter-id'},
        unitIdToAbbreviation: {'meter-id': 'm'},
        category: 'test',
        upvotes: 0,
        myVoteVerdict: 0,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      controller.onAnswerChanged(const AnswerValue(
        number: 42,
        orderOfMagnitude: '',
        unit: 'm',
      ));

      // Act - submit first time
      await controller.submitAnswer();

      // Try to submit again
      await controller.submitAnswer();

      // Assert - should only be called once
      verify(() => mockRealtime.submitAnswer(any(), any(), any())).called(1);

      questionStream.close();
    });

    test('should not submit in review mode', () async {
      // Arrange
      final gameStream = StreamController<GameSnapshot>();
      when(() => mockRealtime.watchGame(testGameId))
          .thenAnswer((_) => gameStream.stream);

      controller.attach();

      gameStream.add(const GameSnapshot(
        state: GameState.questionLastFinished,
        isHost: false,
        questionNumber: testQuestionCount,
        nQuestions: testQuestionCount,
        players: {
          testPlayerId: PlayerSummary(
            playerId: testPlayerId,
            name: 'Test Player',
            pictureUrl: null,
            score: 0,
            isHost: false,
            isActive: true,
            rank: 1,
          ),
        },
        questionUids: ['q1', 'q2', 'q3'],
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.isReviewMode, isTrue);

      controller.onAnswerChanged(const AnswerValue(
        number: 42,
        orderOfMagnitude: '',
        unit: 'm',
      ));

      // Act
      await controller.submitAnswer();

      // Assert - should not submit
      verifyNever(() => mockRealtime.submitAnswer(any(), any(), any()));

      gameStream.close();
    });
  });
}
