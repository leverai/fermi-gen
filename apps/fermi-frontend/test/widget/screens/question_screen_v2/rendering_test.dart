import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/screens/question_v2/widgets/game_carousel.dart';
import 'package:fermi_frontend/widgets/players_row.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'question_screen_v2_test_helpers.dart';
import '../../../fixtures/question_data.dart';

void main() {
  setupQuestionScreenV2Tests();

  group('QuestionScreenV2 - Rendering', () {
    late MockGameRealtimeWithStream mockRealtimeHelper;

    setUp(() {
      mockRealtimeHelper = createMockRealtimeWithStream(
        currentPlayerId: 'player_1',
        gameId: 'game_123',
      );
    });

    tearDown(() {
      mockRealtimeHelper.dispose();
    });

    testWidgets('should display players row', (tester) async {
      // ARRANGE
      final snapshot = createSnapshotWithQuestion(
        questionUid: 'question_1',
        currentPlayerId: 'player_1',
        questionNumber: 1,
        nQuestions: 5,
        isHost: true,
      );

      setupQuestionStreams(
        mockRealtimeHelper,
        'game_123',
        0,
        revealedQuestion: QuestionDataFixtures.question1(),
      );

      // ACT
      await pumpQuestionScreen(
        tester,
        gameId: 'game_123',
        realtime: mockRealtimeHelper.mock,
        questionCount: 5,
        isHost: true,
      );

      // Emit initial snapshot
      mockRealtimeHelper.streamController.add(snapshot);
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.byType(PlayersRow), findsOneWidget);
    });

    testWidgets('should display game carousel', (tester) async {
      // ARRANGE
      final snapshot = createSnapshotWithQuestion(
        questionUid: 'question_1',
        currentPlayerId: 'player_1',
        questionNumber: 1,
        nQuestions: 5,
        isHost: true,
      );

      setupQuestionStreams(
        mockRealtimeHelper,
        'game_123',
        0,
        revealedQuestion: QuestionDataFixtures.question1(),
      );

      // ACT
      await pumpQuestionScreen(
        tester,
        gameId: 'game_123',
        realtime: mockRealtimeHelper.mock,
        questionCount: 5,
        isHost: true,
      );

      // Emit initial snapshot
      mockRealtimeHelper.streamController.add(snapshot);
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.byType(GameCarousel), findsOneWidget);
    });

    testWidgets('should display submit button', (tester) async {
      // ARRANGE
      final snapshot = createSnapshotWithQuestion(
        questionUid: 'question_1',
        currentPlayerId: 'player_1',
        questionNumber: 1,
        nQuestions: 5,
        isHost: true,
      );

      setupQuestionStreams(
        mockRealtimeHelper,
        'game_123',
        0,
        revealedQuestion: QuestionDataFixtures.question1(),
      );

      // ACT
      await pumpQuestionScreen(
        tester,
        gameId: 'game_123',
        realtime: mockRealtimeHelper.mock,
        questionCount: 5,
        isHost: true,
      );

      // Emit initial snapshot
      mockRealtimeHelper.streamController.add(snapshot);
      await tester.pumpAndSettle();

      // ASSERT
      // MainButton is now inside GameCard, so we should find at least one
      expect(find.byType(MainButton), findsAtLeastNWidgets(1));
    });

    testWidgets('should display leave button', (tester) async {
      // ARRANGE
      final snapshot = createSnapshotWithQuestion(
        questionUid: 'question_1',
        currentPlayerId: 'player_1',
        questionNumber: 1,
        nQuestions: 5,
        isHost: true,
      );

      setupQuestionStreams(
        mockRealtimeHelper,
        'game_123',
        0,
        revealedQuestion: QuestionDataFixtures.question1(),
      );

      // ACT
      await pumpQuestionScreen(
        tester,
        gameId: 'game_123',
        realtime: mockRealtimeHelper.mock,
        questionCount: 5,
        isHost: true,
        showLeaveButton: true,
      );

      // Emit initial snapshot
      mockRealtimeHelper.streamController.add(snapshot);
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.byType(LeaveButtonOverlay), findsOneWidget);
    });
  });
}
