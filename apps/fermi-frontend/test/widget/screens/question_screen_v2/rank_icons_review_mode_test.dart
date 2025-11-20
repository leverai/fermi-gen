import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2_controller.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/widgets/rank_widget.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'question_screen_v2_test_helpers.dart';
import '../../../fixtures/question_data.dart';
import '../../../fixtures/player_data.dart';
import '../../../fixtures/game_snapshots.dart';

void main() {
  setupQuestionScreenV2Tests();

  group('Rank Icons in Review Mode', () {
    late MockGameRealtimeWithStream mockRealtimeHelper;
    const String testPlayerId = 'player_1';
    const String testGameId = 'game_123';
    const int questionCount = 3;

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
        'finalRanks should be calculated from cumulativeScores when review mode activates',
        (tester) async {
      // ARRANGE: Set up final question with cumulative scores
      // Final cumulative scores: player_1=120, player_2=110, player_3=80
      // Expected final ranks: player_1=1st, player_2=2nd, player_3=3rd

      // Set up final question streams
      setupQuestionStreams(
        mockRealtimeHelper,
        testGameId,
        2, // Final question (index 2)
        revealedQuestion: QuestionDataFixtures.question3(),
        playersAnswers: const PlayersAnswersSnapshot(
          submitted: {
            'player_1':
                AnswerValue(number: 3, orderOfMagnitude: 'M', unit: 's'),
            'player_2':
                AnswerValue(number: 2, orderOfMagnitude: 'M', unit: 's'),
            'player_3':
                AnswerValue(number: 5, orderOfMagnitude: 'M', unit: 's'),
          },
          scores: {
            'player_1': 30.0, // This adds to previous cumulative scores
            'player_2': 20.0,
            'player_3': 50.0,
          },
          allAnswered: true,
          correct: {
            'player_1': AnswerValue(number: 3, orderOfMagnitude: 'M', unit: 's')
          },
          percentiles: {
            'player_1': 0.8,
            'player_2': 0.5,
            'player_3': 0.95,
          },
        ),
      );

      // Set up previous questions to establish cumulative scores
      // Question 0: player_1=50, player_2=30, player_3=20
      setupQuestionStreams(
        mockRealtimeHelper,
        testGameId,
        0,
        revealedQuestion: QuestionDataFixtures.question1(),
        playersAnswers: const PlayersAnswersSnapshot(
          submitted: {
            'player_1':
                AnswerValue(number: 5, orderOfMagnitude: 'M', unit: 'p'),
            'player_2':
                AnswerValue(number: 3, orderOfMagnitude: 'M', unit: 'p'),
            'player_3':
                AnswerValue(number: 2, orderOfMagnitude: 'M', unit: 'p'),
          },
          scores: {
            'player_1': 50.0,
            'player_2': 30.0,
            'player_3': 20.0,
          },
          allAnswered: true,
          correct: {
            'player_1': AnswerValue(number: 8, orderOfMagnitude: 'M', unit: 'p')
          },
          percentiles: {
            'player_1': 0.9,
            'player_2': 0.7,
            'player_3': 0.5,
          },
        ),
      );

      // Question 1: player_1=40, player_2=60, player_3=10
      // Cumulative after Q1: player_1=90, player_2=90, player_3=30
      setupQuestionStreams(
        mockRealtimeHelper,
        testGameId,
        1,
        revealedQuestion: QuestionDataFixtures.question2(),
        playersAnswers: const PlayersAnswersSnapshot(
          submitted: {
            'player_1':
                AnswerValue(number: 4, orderOfMagnitude: 'E', unit: 'kg'),
            'player_2':
                AnswerValue(number: 6, orderOfMagnitude: 'E', unit: 'kg'),
            'player_3':
                AnswerValue(number: 1, orderOfMagnitude: 'E', unit: 'kg'),
          },
          scores: {
            'player_1': 40.0,
            'player_2': 60.0,
            'player_3': 10.0,
          },
          allAnswered: true,
          correct: {
            'player_1':
                AnswerValue(number: 6, orderOfMagnitude: 'E', unit: 'kg')
          },
          percentiles: {
            'player_1': 0.6,
            'player_2': 0.95,
            'player_3': 0.2,
          },
        ),
      );

      // Final snapshot: game finished, review mode activates
      final finalSnapshot = GameSnapshotFixtures.gameFinished(
        currentPlayerId: testPlayerId,
        nQuestions: questionCount,
        isHost: true,
        questionUids: ['question_1', 'question_2', 'question_3'],
        players: {
          'player_1': PlayerDataFixtures.player(
            playerId: 'player_1',
            name: 'Alice',
            score: 120.0, // Final cumulative: 50 + 40 + 30
            rank: 1,
            isHost: true,
          ),
          'player_2': PlayerDataFixtures.player(
            playerId: 'player_2',
            name: 'Bob',
            score: 110.0, // Final cumulative: 30 + 60 + 20
            rank: 2,
          ),
          'player_3': PlayerDataFixtures.player(
            playerId: 'player_3',
            name: 'Charlie',
            score: 80.0, // Final cumulative: 20 + 10 + 50
            rank: 3,
          ),
        },
      );

      // ACT: Pump the screen
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

      // Emit final snapshot (game finished) - this should trigger review mode
      mockRealtimeHelper.streamController.add(finalSnapshot);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Wait for review mode to activate and finalRanks to be calculated
      await tester.pump(const Duration(milliseconds: 1000));
      // Wait for confetti timer to complete (12 seconds)
      await tester.pump(const Duration(milliseconds: 12000));

      // ASSERT: Verify finalRanks is correctly calculated from cumulativeScores
      expect(testController, isNotNull,
          reason: 'Controller should be accessible');

      final finalRanks = testController!.finalRanks;
      expect(finalRanks, isNotNull,
          reason: 'finalRanks should be calculated when review mode activates');
      expect(finalRanks!['player_1'], Rank.first,
          reason:
              'player_1 should have gold (1st place) based on final cumulative score of 120');
      expect(finalRanks['player_2'], Rank.second,
          reason:
              'player_2 should have silver (2nd place) based on final cumulative score of 110');
      expect(finalRanks['player_3'], Rank.third,
          reason:
              'player_3 should have bronze (3rd place) based on final cumulative score of 80');

      // Verify review mode is active
      expect(testController!.isReviewMode, true,
          reason: 'Review mode should be active after final question');

      // Verify that finalRanks persists when navigating to earlier questions
      // Navigate to question 0 (where player_1 was 1st, player_2 was 2nd, player_3 was 3rd in that question)
      // But final ranks should still show: player_1=gold, player_2=silver, player_3=bronze
      testController!.onCarouselPageChanged(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final finalRanksAfterNav = testController!.finalRanks;
      expect(finalRanksAfterNav, isNotNull,
          reason: 'finalRanks should persist after navigation');
      expect(finalRanksAfterNav!['player_1'], Rank.first,
          reason:
              'player_1 should still have gold even when viewing question 0');
      expect(finalRanksAfterNav['player_2'], Rank.second,
          reason:
              'player_2 should still have silver even when viewing question 0');
      expect(finalRanksAfterNav['player_3'], Rank.third,
          reason:
              'player_3 should still have bronze even when viewing question 0');
    });
  });
}
