import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2_controller.dart';

/// Mock GameRealtime for testing
class MockGameRealtime extends Mock implements GameRealtime {}

// Test constants
const String testGameId = 'test-game-123';
const int testQuestionCount = 3;
const String testPlayerId = 'player-1';

// Helper to create a default mock realtime with all standard behaviors
MockGameRealtime createMockRealtime() {
  final mockRealtime = MockGameRealtime();

  // Setup default mock behavior
  when(() => mockRealtime.currentPlayerId).thenReturn(testPlayerId);
  when(() => mockRealtime.currentLocale).thenReturn('US');
  when(() => mockRealtime.watchGame(any())).thenAnswer(
    (_) => Stream<GameSnapshot>.value(
      const GameSnapshot(
        state: GameState.questionN,
        isHost: false,
        questionNumber: 1,
        nQuestions: testQuestionCount,
        durationSeconds: 15,
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
      ),
    ),
  );
  when(() => mockRealtime.submitAnswer(any(), any(), any()))
      .thenAnswer((_) async {});
  when(() => mockRealtime.goNext(any())).thenAnswer((_) async {});
  when(() => mockRealtime.revealedQuestion(any(), any()))
      .thenAnswer((_) => const Stream<RevealedQuestion>.empty());
  when(() => mockRealtime.revealsForQuestion(any(), any()))
      .thenAnswer((_) => const Stream<RevealPayload>.empty());
  when(() => mockRealtime.playersAnswersForQuestion(any(), any()))
      .thenAnswer((_) => const Stream<PlayersAnswersSnapshot>.empty());

  return mockRealtime;
}

// Helper to create a controller with default setup
QuestionScreenV2Controller createController(MockGameRealtime mockRealtime) {
  return QuestionScreenV2Controller(
    realtime: mockRealtime,
    gameId: testGameId,
    questionCount: testQuestionCount,
  );
}
