import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2_controller.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/theme/colormap.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'question_screen_v2_test_helpers.dart';
import '../../../fixtures/question_data.dart';

void main() {
  setupQuestionScreenV2Tests();

  group('Leaving Card State Preservation', () {
    late MockGameRealtimeWithStream mockRealtimeHelper;
    const String testPlayerId = 'player_1';
    const String testGameId = 'game_123';
    const int questionCount = 2;

    setUp(() {
      mockRealtimeHelper = createMockRealtimeWithStream(
        currentPlayerId: testPlayerId,
        gameId: testGameId,
      );
    });

    tearDown(() {
      mockRealtimeHelper.dispose();
    });

    testWidgets(
        'LC should maintain all state after carousel advances to next question',
        (tester) async {
      // ARRANGE: Set up initial state for question 0 (LC)
      const lcQuestionText = QuestionDataFixtures.sampleQuestion1;
      const lcTags = QuestionDataFixtures.geographyTags;
      const lcSubmittedAnswer =
          AnswerValue(number: 5, orderOfMagnitude: 'M', unit: 'p');
      const lcCorrectAnswer =
          AnswerValue(number: 8, orderOfMagnitude: 'M', unit: 'p');
      const lcScore = 75.0; // High score for green color
      final lcRevealedColor = scoreToColor(lcScore.round());

      // Set up question 0 (LC) streams
      setupQuestionStreams(
        mockRealtimeHelper,
        testGameId,
        0,
        revealedQuestion: QuestionDataFixtures.question1(),
        playersAnswers: const PlayersAnswersSnapshot(
          submitted: {testPlayerId: lcSubmittedAnswer},
          scores: {testPlayerId: lcScore},
          allAnswered: true,
          correct: {testPlayerId: lcCorrectAnswer},
          percentiles: {testPlayerId: 0.85},
        ),
      );

      // Set up question 1 (IC) streams
      setupQuestionStreams(
        mockRealtimeHelper,
        testGameId,
        1,
        revealedQuestion: QuestionDataFixtures.question2(),
      );

      // Initial snapshot: question 0 is current
      final initialSnapshot = createSnapshotWithQuestion(
        questionUid: 'question_1',
        currentPlayerId: testPlayerId,
        questionNumber: 1,
        nQuestions: questionCount,
        isHost: true,
        players: {
          testPlayerId: const PlayerSummary(
            playerId: testPlayerId,
            name: 'Test Player',
            score: 0.0,
            isHost: true,
            isActive: true,
            rank: 1,
          ),
        },
      );

      // Next snapshot: question 1 is current (after "Next" button)
      final nextSnapshot = createSnapshotWithQuestion(
        questionUid: 'question_2',
        currentPlayerId: testPlayerId,
        questionNumber: 2,
        nQuestions: questionCount,
        isHost: true,
        players: {
          testPlayerId: const PlayerSummary(
            playerId: testPlayerId,
            name: 'Test Player',
            score: lcScore,
            isHost: true,
            isActive: true,
            rank: 1,
          ),
        },
      );

      // ACT: Pump the screen with controller access
      // Set a larger screen size for QuestionScreenV2 tests
      // The screen has fixed layout calculations that need more space
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      QuestionScreenV2Controller? testController;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: <ThemeExtension<dynamic>>[
              AppTheme.defaultTheme(),
              const AppFont(),
            ],
          ),
          home: QuestionScreenV2(
            gameId: testGameId,
            realtime: mockRealtimeHelper.mock,
            questionCount: questionCount,
            isHost: true,
            onControllerCreated: (ctrl) {
              testController = ctrl;
            },
          ),
        ),
      );

      // Emit initial snapshot
      mockRealtimeHelper.streamController.add(initialSnapshot);
      // Use pump with timeout instead of pumpAndSettle to avoid infinite loops
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Wait for reveal animation to complete
      await tester.pump(const Duration(milliseconds: 700));

      // Verify controller is accessible
      expect(testController, isNotNull,
          reason: 'Controller should be accessible');

      // Verify LC state before advancement
      final lcStateBefore = testController!.getQuestionState(0);
      expect(lcStateBefore, isNotNull,
          reason: 'LC state should exist before advancement');
      expect(lcStateBefore!.questionText, lcQuestionText);
      expect(lcStateBefore.tags, lcTags);
      expect(lcStateBefore.isRevealed, true);
      expect(lcStateBefore.correctAnswer, lcCorrectAnswer);
      expect(lcStateBefore.submittedAnswers[testPlayerId], lcSubmittedAnswer);

      // ACT: Advance to question 1 (IC) by simulating "Next" button press
      final nextButton = find.text('Next');
      expect(nextButton, findsOneWidget,
          reason: 'Next button should be visible');

      // Tap the Next button
      await tester.tap(nextButton);
      await tester.pump();

      // Emit new snapshot: question 1 is now current
      mockRealtimeHelper.streamController.add(nextSnapshot);
      // Use pump with specific durations instead of pumpAndSettle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Wait for carousel animation to complete
      await tester.pump(const Duration(milliseconds: 600));

      // ASSERT: Verify LC state is preserved after advancement
      final lcStateAfter = testController!.getQuestionState(0);
      expect(lcStateAfter, isNotNull,
          reason: 'LC state should still exist after advancement');

      // 1. Question widget text and tags
      expect(
        lcStateAfter!.questionText,
        lcQuestionText,
        reason: 'LC question text should be preserved',
      );
      expect(
        lcStateAfter.tags,
        lcTags,
        reason: 'LC question tags should be preserved',
      );

      // 2. Question widget text color (score scale)
      final lcRevealedColorAfter = testController!.getRevealedColor(0);
      expect(
        lcRevealedColorAfter,
        lcRevealedColor,
        reason: 'LC question text color (score scale) should be preserved',
      );

      // 3. Answer widget values (3 digits, om, unit)
      final lcDisplayAnswer = testController!.getDisplayAnswer(0);
      expect(
        lcDisplayAnswer.number,
        lcCorrectAnswer.number,
        reason: 'LC answer widget digit value should be preserved',
      );
      expect(
        lcDisplayAnswer.orderOfMagnitude,
        lcCorrectAnswer.orderOfMagnitude,
        reason: 'LC answer widget OM value should be preserved',
      );
      expect(
        lcDisplayAnswer.unit,
        lcCorrectAnswer.unit,
        reason: 'LC answer widget unit value should be preserved',
      );

      // 4. Answer widget text colors (score scale) - same as question widget
      // The revealedColor is applied to both question and answer widgets
      expect(
        lcRevealedColorAfter,
        lcRevealedColor,
        reason: 'LC answer widget text color (score scale) should be preserved',
      );

      // 5. Answer widget tap indicators - should be hidden
      // This is verified by checking that the question is revealed (editable = false)
      expect(
        lcStateAfter.isRevealed,
        true,
        reason: 'LC should remain revealed (tap indicators hidden)',
      );

      // 6. Mirror text widget should show the player's answer
      expect(
        lcStateAfter.submittedAnswers[testPlayerId],
        lcSubmittedAnswer,
        reason: 'LC mirror text should show player\'s submitted answer',
      );

      // Additional verification: Ensure the correct answer is preserved
      expect(
        lcStateAfter.correctAnswer,
        lcCorrectAnswer,
        reason: 'LC correct answer should be preserved',
      );

      // Verify scores are preserved
      expect(
        lcStateAfter.scores[testPlayerId],
        lcScore,
        reason: 'LC score should be preserved',
      );
    });
  });
}
