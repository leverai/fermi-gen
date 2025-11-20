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

  group('QuestionScreenV2Controller - Answer Leakage Prevention', () {
    late MockGameRealtime mockRealtime;
    late QuestionScreenV2Controller controller;

    setUp(() {
      mockRealtime = createMockRealtime();
      controller = createController(mockRealtime);
    });

    tearDown(() {
      controller.dispose();
    });

    test('should not leak answer values when navigating between questions',
        () async {
      // ARRANGE: Set up game stream and question streams
      final gameStreamController = StreamController<GameSnapshot>.broadcast();
      when(() => mockRealtime.watchGame(testGameId))
          .thenAnswer((_) => gameStreamController.stream);

      // Set up question streams for all questions
      final questionStreams = <int, StreamController<RevealedQuestion>>{};
      for (int i = 0; i < testQuestionCount; i++) {
        final stream = StreamController<RevealedQuestion>();
        questionStreams[i] = stream;
        when(() => mockRealtime.revealedQuestion(testGameId, i))
            .thenAnswer((_) => stream.stream);
      }

      controller.attach();

      // Emit initial game snapshot (question 0)
      gameStreamController.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: false,
        questionNumber: 1,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      // Emit question 0 data
      questionStreams[0]!.add(const RevealedQuestion(
        text: 'Question 0',
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

      // ACT: Enter answer for question 0
      const answer0 =
          AnswerValue(number: 123, orderOfMagnitude: 'K', unit: 'm');
      controller.onAnswerChanged(answer0);

      // Verify answer is set for question 0
      expect(controller.getDisplayAnswer(0), equals(answer0));
      expect(controller.currentAnswer, equals(answer0));

      // ACT: Navigate to question 1 via backend
      gameStreamController.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: false,
        questionNumber: 2, // Question index 1 (0-based)
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      // Emit question 1 data
      questionStreams[1]!.add(const RevealedQuestion(
        text: 'Question 1',
        tags: [],
        units: ['kg', 'g'],
        unitOptions: {'Kilogram': 'kg', 'Gram': 'g'},
        unitAbbreviationToId: {'kg': 'kg-id', 'g': 'g-id'},
        unitIdToAbbreviation: {'kg-id': 'kg', 'g-id': 'g'},
        category: 'test',
        upvotes: 0,
        myVoteVerdict: 0,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // ASSERT: Question 1 should have default answer, not question 0's answer
      final displayAnswer1 = controller.getDisplayAnswer(1);
      expect(displayAnswer1.number, equals(1)); // Default number
      expect(displayAnswer1.orderOfMagnitude, equals('')); // Default OM
      expect(displayAnswer1.unit, equals('kg')); // First unit from question 1
      expect(displayAnswer1,
          isNot(equals(answer0))); // Should NOT be question 0's answer

      // ASSERT: Question 0 should still have its answer
      final state0 = controller.getQuestionState(0);
      expect(state0?.userAnswer, equals(answer0));

      // Cleanup
      gameStreamController.close();
      for (final stream in questionStreams.values) {
        stream.close();
      }
    });

    test('should preserve per-question answers when navigating back', () async {
      // ARRANGE: Set up game stream and question streams
      final gameStreamController = StreamController<GameSnapshot>.broadcast();
      when(() => mockRealtime.watchGame(testGameId))
          .thenAnswer((_) => gameStreamController.stream);

      final questionStreams = <int, StreamController<RevealedQuestion>>{};
      for (int i = 0; i < testQuestionCount; i++) {
        final stream = StreamController<RevealedQuestion>();
        questionStreams[i] = stream;
        when(() => mockRealtime.revealedQuestion(testGameId, i))
            .thenAnswer((_) => stream.stream);
      }

      controller.attach();

      // Set up question 0
      gameStreamController.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: false,
        questionNumber: 1,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      questionStreams[0]!.add(const RevealedQuestion(
        text: 'Question 0',
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

      // Enter answer for question 0
      const answer0 = AnswerValue(number: 100, orderOfMagnitude: '', unit: 'm');
      controller.onAnswerChanged(answer0);

      // Navigate to question 1
      gameStreamController.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: false,
        questionNumber: 2,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      questionStreams[1]!.add(const RevealedQuestion(
        text: 'Question 1',
        tags: [],
        units: ['kg'],
        unitOptions: {'Kilogram': 'kg'},
        unitAbbreviationToId: {'kg': 'kg-id'},
        unitIdToAbbreviation: {'kg-id': 'kg'},
        category: 'test',
        upvotes: 0,
        myVoteVerdict: 0,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Enter answer for question 1
      const answer1 =
          AnswerValue(number: 200, orderOfMagnitude: 'K', unit: 'kg');
      controller.onAnswerChanged(answer1);

      // Navigate back to question 0
      gameStreamController.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: false,
        questionNumber: 1,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // ASSERT: Question 0 should still have its original answer
      expect(controller.getDisplayAnswer(0), equals(answer0));
      expect(controller.getDisplayAnswer(0), isNot(equals(answer1)));

      // ASSERT: Question 1 should still have its answer
      final state1 = controller.getQuestionState(1);
      expect(state1?.userAnswer, equals(answer1));

      // Cleanup
      gameStreamController.close();
      for (final stream in questionStreams.values) {
        stream.close();
      }
    });

    test('should clear animation state when navigating during reveal animation',
        () async {
      // ARRANGE: Set up game stream and question streams
      final gameStreamController = StreamController<GameSnapshot>.broadcast();
      when(() => mockRealtime.watchGame(testGameId))
          .thenAnswer((_) => gameStreamController.stream);

      final questionStreams = <int, StreamController<RevealedQuestion>>{};
      final revealStreams = <int, StreamController<RevealPayload>>{};
      for (int i = 0; i < testQuestionCount; i++) {
        final qStream = StreamController<RevealedQuestion>();
        questionStreams[i] = qStream;
        when(() => mockRealtime.revealedQuestion(testGameId, i))
            .thenAnswer((_) => qStream.stream);

        final rStream = StreamController<RevealPayload>();
        revealStreams[i] = rStream;
        when(() => mockRealtime.revealsForQuestion(testGameId, i))
            .thenAnswer((_) => rStream.stream);
      }

      controller.attach();

      // Set up question 0
      gameStreamController.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: false,
        questionNumber: 1,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      questionStreams[0]!.add(const RevealedQuestion(
        text: 'Question 0',
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

      // Start reveal animation for question 0
      const correctAnswer0 =
          AnswerValue(number: 500, orderOfMagnitude: 'K', unit: 'm');
      revealStreams[0]!.add(const RevealPayload(correct: correctAnswer0));

      await Future.delayed(const Duration(milliseconds: 10));

      // Verify animation state is set
      expect(controller.getDisplayAnswer(0).number, greaterThanOrEqualTo(1));

      // ACT: Navigate to question 1 BEFORE animation completes
      gameStreamController.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: false,
        questionNumber: 2,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      questionStreams[1]!.add(const RevealedQuestion(
        text: 'Question 1',
        tags: [],
        units: ['kg'],
        unitOptions: {'Kilogram': 'kg'},
        unitAbbreviationToId: {'kg': 'kg-id'},
        unitIdToAbbreviation: {'kg-id': 'kg'},
        category: 'test',
        upvotes: 0,
        myVoteVerdict: 0,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // ASSERT: Animation state should be cleared
      // Question 1 should show default answer, not animation progress from question 0
      final displayAnswer1 = controller.getDisplayAnswer(1);
      expect(displayAnswer1.number, equals(1)); // Default, not animation value
      expect(displayAnswer1.unit, equals('kg')); // First unit from question 1

      // Cleanup
      gameStreamController.close();
      for (final stream in questionStreams.values) {
        stream.close();
      }
      for (final stream in revealStreams.values) {
        stream.close();
      }
    });

    test(
        'should initialize new question with default answer, not previous question answer',
        () async {
      // ARRANGE: Set up game stream and question streams
      final gameStreamController = StreamController<GameSnapshot>.broadcast();
      when(() => mockRealtime.watchGame(testGameId))
          .thenAnswer((_) => gameStreamController.stream);

      final questionStreams = <int, StreamController<RevealedQuestion>>{};
      for (int i = 0; i < testQuestionCount; i++) {
        final stream = StreamController<RevealedQuestion>();
        questionStreams[i] = stream;
        when(() => mockRealtime.revealedQuestion(testGameId, i))
            .thenAnswer((_) => stream.stream);
      }

      controller.attach();

      // Set up question 0 with custom units
      gameStreamController.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: false,
        questionNumber: 1,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      questionStreams[0]!.add(const RevealedQuestion(
        text: 'Question 0',
        tags: [],
        units: ['m', 'km'],
        unitOptions: {'Meter': 'm', 'Kilometer': 'km'},
        unitAbbreviationToId: {'m': 'meter-id', 'km': 'km-id'},
        unitIdToAbbreviation: {'meter-id': 'm', 'km-id': 'km'},
        category: 'test',
        upvotes: 0,
        myVoteVerdict: 0,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Enter answer for question 0
      const answer0 =
          AnswerValue(number: 999, orderOfMagnitude: 'M', unit: 'km');
      controller.onAnswerChanged(answer0);

      // ACT: Navigate to question 1 with different units
      gameStreamController.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: false,
        questionNumber: 2,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
        players: {},
        isPrivate: false,
        questionUids: ['q1', 'q2', 'q3'],
      ));

      questionStreams[1]!.add(const RevealedQuestion(
        text: 'Question 1',
        tags: [],
        units: ['kg', 'g'], // Different units
        unitOptions: {'Kilogram': 'kg', 'Gram': 'g'},
        unitAbbreviationToId: {'kg': 'kg-id', 'g': 'g-id'},
        unitIdToAbbreviation: {'kg-id': 'kg', 'g-id': 'g'},
        category: 'test',
        upvotes: 0,
        myVoteVerdict: 0,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // ASSERT: Question 1 should have default answer with its own first unit
      final displayAnswer1 = controller.getDisplayAnswer(1);
      expect(displayAnswer1.number, equals(1)); // Default number
      expect(displayAnswer1.orderOfMagnitude, equals('')); // Default OM
      expect(displayAnswer1.unit,
          equals('kg')); // First unit from question 1, NOT 'km' from question 0
      expect(displayAnswer1,
          isNot(equals(answer0))); // Should NOT match question 0's answer

      // Cleanup
      gameStreamController.close();
      for (final stream in questionStreams.values) {
        stream.close();
      }
    });
  });
}
