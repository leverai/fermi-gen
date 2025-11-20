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

  group('QuestionScreenV2Controller - Deadline Timer', () {
    late MockGameRealtime mockRealtime;
    late QuestionScreenV2Controller controller;

    setUp(() {
      mockRealtime = createMockRealtime();
      controller = createController(mockRealtime);
    });

    tearDown(() {
      controller.dispose();
    });

    test('should start timer when question becomes active', () async {
      // Arrange
      final questionStream = StreamController<RevealedQuestion>();
      when(() => mockRealtime.revealedQuestion(testGameId, 0))
          .thenAnswer((_) => questionStream.stream);

      controller.attach();

      // Act - emit question
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

      // Assert - deadline tracker should be active
      expect(controller.deadlineProgressTracker, isNotNull);
      expect(controller.deadlineProgressTracker?.isActive, isTrue);

      questionStream.close();
    });

    test('should stop timer when question revealed', () async {
      // Arrange
      final questionStream = StreamController<RevealedQuestion>();
      final revealStream = StreamController<RevealPayload>();
      when(() => mockRealtime.revealedQuestion(testGameId, 0))
          .thenAnswer((_) => questionStream.stream);
      when(() => mockRealtime.revealsForQuestion(testGameId, 0))
          .thenAnswer((_) => revealStream.stream);

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

      expect(controller.deadlineProgressTracker?.isActive, isTrue);

      // Act - emit reveal
      revealStream.add(const RevealPayload(
        correct: AnswerValue(number: 100, orderOfMagnitude: '', unit: 'm'),
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Assert - timer should be stopped
      expect(controller.deadlineProgressTracker?.isActive, isFalse);

      questionStream.close();
      revealStream.close();
    });

    test('should not start timer in review mode', () async {
      // Arrange
      final gameStream = StreamController<GameSnapshot>();
      when(() => mockRealtime.watchGame(testGameId))
          .thenAnswer((_) => gameStream.stream);

      controller.attach();

      // Set review mode
      gameStream.add(const GameSnapshot(
        state: GameState.questionLastFinished,
        isHost: false,
        questionNumber: testQuestionCount,
        nQuestions: testQuestionCount,
        durationSeconds: 0,
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
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.isReviewMode, isTrue);

      final questionStream = StreamController<RevealedQuestion>();
      when(() => mockRealtime.revealedQuestion(testGameId, 0))
          .thenAnswer((_) => questionStream.stream);

      // Act - emit question in review mode
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

      // Assert - timer should not be active
      expect(controller.deadlineProgressTracker?.isActive, isFalse);

      questionStream.close();
      gameStream.close();
    });

    test('should not start timer if duration is zero', () async {
      // Arrange
      final gameStream = StreamController<GameSnapshot>();
      when(() => mockRealtime.watchGame(testGameId))
          .thenAnswer((_) => gameStream.stream);

      controller.attach();

      // Set game with zero duration
      gameStream.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: false,
        questionNumber: 1,
        nQuestions: testQuestionCount,
        durationSeconds: 0, // zero duration
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
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      final questionStream = StreamController<RevealedQuestion>();
      when(() => mockRealtime.revealedQuestion(testGameId, 0))
          .thenAnswer((_) => questionStream.stream);

      // Act - emit question
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

      // Assert - timer should not be active
      expect(controller.deadlineProgressTracker?.isActive, isFalse);

      questionStream.close();
      gameStream.close();
    });
  });
}
