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

  group('QuestionScreenV2Controller - Host Controls', () {
    late MockGameRealtime mockRealtime;
    late QuestionScreenV2Controller controller;

    setUp(() {
      mockRealtime = createMockRealtime();
      controller = createController(mockRealtime);
    });

    tearDown(() {
      controller.dispose();
    });

    test('should allow host to request next question', () async {
      // Arrange
      final gameStream = StreamController<GameSnapshot>();
      when(() => mockRealtime.watchGame(testGameId))
          .thenAnswer((_) => gameStream.stream);

      controller.attach();

      // Set user as host
      gameStream.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: true, // User is host
        questionNumber: 1,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Act
      await controller.requestNext();

      // Assert
      verify(() => mockRealtime.goNext(testGameId)).called(1);

      gameStream.close();
    });

    test('should NOT allow non-host to request next question', () async {
      // Arrange
      final gameStream = StreamController<GameSnapshot>();
      when(() => mockRealtime.watchGame(testGameId))
          .thenAnswer((_) => gameStream.stream);

      controller.attach();

      // Set user as non-host
      gameStream.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: false, // User is NOT host
        questionNumber: 1,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Act
      await controller.requestNext();

      // Assert
      verifyNever(() => mockRealtime.goNext(any()));

      gameStream.close();
    });

    test('should NOT allow host to request next in review mode', () async {
      // Arrange
      final gameStream = StreamController<GameSnapshot>();
      when(() => mockRealtime.watchGame(testGameId))
          .thenAnswer((_) => gameStream.stream);

      controller.attach();

      // Set user as host but in review mode
      gameStream.add(const GameSnapshot(
        state: GameState.questionLastFinished, // Review mode
        isHost: true,
        questionNumber: testQuestionCount,
        nQuestions: testQuestionCount,
        durationSeconds: 0,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Act
      await controller.requestNext();

      // Assert
      verifyNever(() => mockRealtime.goNext(any()));

      gameStream.close();
    });

    test('should auto-trigger next if host when auto-next timer completes',
        () async {
      // Arrange
      final gameStream = StreamController<GameSnapshot>();
      final questionStream = StreamController<RevealedQuestion>();
      final revealStream = StreamController<RevealPayload>();

      when(() => mockRealtime.watchGame(testGameId))
          .thenAnswer((_) => gameStream.stream);
      when(() => mockRealtime.revealedQuestion(testGameId, 0))
          .thenAnswer((_) => questionStream.stream);
      when(() => mockRealtime.revealsForQuestion(testGameId, 0))
          .thenAnswer((_) => revealStream.stream);

      controller.attach();

      // Set user as host
      gameStream.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: true,
        questionNumber: 1,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

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

      // Act - Emit reveal to start auto-next timer
      revealStream.add(const RevealPayload(
        correct: AnswerValue(number: 100, orderOfMagnitude: '', unit: 'm'),
      ));

      // Wait for timer to start
      await Future.delayed(const Duration(milliseconds: 200));
      expect(controller.autoNextProgress, greaterThan(0));
    });
  });
}
