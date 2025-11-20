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

  group('QuestionScreenV2Controller - Answer Submission', () {
    late MockGameRealtime mockRealtime;
    late QuestionScreenV2Controller controller;

    setUp(() {
      mockRealtime = createMockRealtime();
      controller = createController(mockRealtime);
    });

    tearDown(() {
      controller.dispose();
    });

    test('should submit answer via realtime', () async {
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
        orderOfMagnitude: 'K',
        unit: 'm',
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
              unit: 'meter-id',
            ),
          )).called(1);

      questionStream.close();
    });

    test('should set local submitted answer', () async {
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

      const answer = AnswerValue(
        number: 42,
        orderOfMagnitude: 'K',
        unit: 'm',
      );
      controller.onAnswerChanged(answer);

      // Act
      await controller.submitAnswer();

      // Assert
      expect(controller.localSubmittedAnswer, equals(answer));

      questionStream.close();
    });

    test('should handle submission errors', () async {
      // Arrange
      final questionStream = StreamController<RevealedQuestion>();
      when(() => mockRealtime.revealedQuestion(testGameId, 0))
          .thenAnswer((_) => questionStream.stream);

      when(() => mockRealtime.submitAnswer(any(), any(), any()))
          .thenThrow(Exception('Network error'));

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

      // Act
      await controller.submitAnswer();

      // Assert
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('Submit failed'));

      questionStream.close();
    });

    test('should wait for unit maps before submission', () async {
      // Arrange
      final questionStream = StreamController<RevealedQuestion>();
      when(() => mockRealtime.revealedQuestion(testGameId, 0))
          .thenAnswer((_) => questionStream.stream);

      controller.attach();

      // Emit question without unit maps
      questionStream.add(const RevealedQuestion(
        text: 'Test question',
        tags: [],
        units: ['m'],
        unitOptions: {'Meter': 'm'},
        unitAbbreviationToId: {}, // empty - maps not ready
        unitIdToAbbreviation: {},
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

      // Act
      await controller.submitAnswer();

      // Assert
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, contains('Please wait'));
      verifyNever(() => mockRealtime.submitAnswer(any(), any(), any()));

      questionStream.close();
    });
  });
}
