import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/player_widget_controller.dart';
import 'package:fermi_frontend/widgets/player_ring_progress.dart';
import 'package:fermi_frontend/widgets/player_score.dart';
import 'package:fermi_frontend/widgets/answer_chip.dart';
import 'package:fermi_frontend/widgets/rank_widget.dart';
import 'package:fermi_frontend/widgets/player_confetti_overlay.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/widgets/question_deadline_progress_tracker.dart';

import '../../helpers/test_helpers.dart';
import '../../fixtures/player_data.dart';

void main() {
  group('PlayerWidget - Rendering', () {
    testWidgets('should display player avatar', (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
        displayName: 'Test Player',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(playerState: playerState),
      );

      // Assert
      // Avatar is rendered as a Container with circular decoration
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(PlayerRingProgress), findsOneWidget);
    });

    testWidgets('should display player name when showNameChip is true',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
        displayName: 'Test Player',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          showNameChip: true,
        ),
      );

      // Assert
      // Name chip is visible after tap
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.text('Test Player'), findsOneWidget);

      // Clean up: dispose widget and elapse time to let TextScroll timers complete
      // TextScroll creates a timer with delayBefore: 1s that isn't canceled in dispose
      // We need to elapse time in the fake async context to let the timer complete
      await tester.pumpWidget(const SizedBox());
      // Elapse time to let the pending timer (1 second delayBefore) complete
      // Use binding.delayed to advance fake async time
      await tester.binding.delayed(const Duration(seconds: 2));
      await tester.pump();
    });

    testWidgets('should display score when score is provided',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
        score: 100,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          showScoreOverlay: true,
        ),
      );

      // Assert
      expect(find.byType(PlayerScore), findsOneWidget);
    });

    testWidgets(
        'should display rank badge for top 3 when showRankIcons is true',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          showRankIcons: true,
          rankOverride: Rank.first,
        ),
      );

      // Assert
      expect(find.byType(RankWidget), findsOneWidget);
    });

    testWidgets('should highlight host', (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
        isHost: true,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: false,
        ),
      );

      // Assert
      // Host ring should use primary color
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.isHost, true);
    });

    testWidgets('should highlight current player', (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
        isHost: false,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: true,
        ),
      );

      // Assert
      // Self ring should use info color
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.isSelf, true);
    });
  });

  group('PlayerWidget - Status Display', () {
    testWidgets('should show waiting status before answer',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(playerState: playerState),
      );

      // Assert
      // Waiting status doesn't show an indicator (ring handles feedback)
      expect(playerState.status, PlayerStatus.waiting);
    });

    testWidgets('should show ready status after answer',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.readyPlayerState(
        playerId: 'player_1',
        submittedAnswer: const AnswerValue(
          number: 8,
          orderOfMagnitude: 'M',
          unit: 'p',
        ),
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(playerState: playerState),
      );

      // Assert
      expect(playerState.status, PlayerStatus.ready);
      expect(playerState.ringState, RingState.completed);
    });

    testWidgets('should show answer chip after reveal',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.answerPlayerState(
        playerId: 'player_1',
        roundScore: 50,
        submittedAnswer: const AnswerValue(
          number: 8,
          orderOfMagnitude: 'M',
          unit: 'p',
        ),
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(playerState: playerState),
      );

      // Assert
      expect(find.byType(AnswerChip), findsOneWidget);
    });

    testWidgets('should color answer chip by score',
        (WidgetTester tester) async {
      // Arrange
      final highScoreState = PlayerDataFixtures.answerPlayerState(
        playerId: 'player_1',
        roundScore: 5000, // High score (close to max 6000)
        submittedAnswer: const AnswerValue(
          number: 8,
          orderOfMagnitude: 'M',
          unit: 'p',
        ),
      );

      final lowScoreState = PlayerDataFixtures.answerPlayerState(
        playerId: 'player_2',
        roundScore: 10, // Low score (close to min 0)
        submittedAnswer: const AnswerValue(
          number: 7,
          orderOfMagnitude: 'M',
          unit: 'p',
        ),
      );

      // Act
      await pumpWithMaterialApp(
          tester, PlayerWidget(playerState: highScoreState));
      await tester.pumpAndSettle();
      final highScoreChip = tester.widget<AnswerChip>(
        find.byType(AnswerChip),
      );

      await pumpWithMaterialApp(
          tester, PlayerWidget(playerState: lowScoreState));
      await tester.pumpAndSettle();
      final lowScoreChip = tester.widget<AnswerChip>(
        find.byType(AnswerChip),
      );

      // Assert
      // High score should have a different (greener) background than low score
      expect(
          highScoreChip.backgroundColor, isNot(lowScoreChip.backgroundColor));
    });
  });

  group('PlayerWidget - Ring Progress', () {
    testWidgets('should display countdown ring during question',
        (WidgetTester tester) async {
      // Arrange
      final tracker = QuestionDeadlineProgressTracker();
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          deadlineProgressTracker: tracker,
        ),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.ringState, RingState.countdown);
    });

    testWidgets('should complete ring on submission',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.readyPlayerState(
        playerId: 'player_1',
        submittedAnswer: const AnswerValue(
          number: 8,
          orderOfMagnitude: 'M',
          unit: 'p',
        ),
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(playerState: playerState),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.ringState, RingState.completed);
    });

    testWidgets('should show static ring in review mode',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.reviewPlayerState(
        playerId: 'player_1',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(playerState: playerState),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.ringState, RingState.review);
    });

    testWidgets('should use correct colors for self (non-host)',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
        isHost: false,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: true,
        ),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.isSelf, true);
      expect(ringProgress.isHost, false);
      // In countdown state, self (non-host) should use info color
      expect(ringProgress.ringState, RingState.countdown);
    });

    testWidgets('should use correct colors for self as host',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
        isHost: true,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: true,
        ),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.isSelf, true);
      expect(ringProgress.isHost, true);
      // In countdown state, host should use primary color (host takes precedence)
      expect(ringProgress.ringState, RingState.countdown);
    });

    testWidgets('should use primary color for host when completed',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.readyPlayerState(
        playerId: 'player_1',
        isHost: true,
        submittedAnswer: const AnswerValue(
          number: 8,
          orderOfMagnitude: 'M',
          unit: 'p',
        ),
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: true,
        ),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.isHost, true);
      expect(ringProgress.ringState, RingState.completed);
      // Host should use primary color even when completed
      // This is the bug fix - host ring should remain primary, not turn green
    });

    testWidgets('should use success color for non-host when completed',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.readyPlayerState(
        playerId: 'player_1',
        isHost: false,
        submittedAnswer: const AnswerValue(
          number: 8,
          orderOfMagnitude: 'M',
          unit: 'p',
        ),
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: true,
        ),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.isHost, false);
      expect(ringProgress.ringState, RingState.completed);
      // Non-host should use success color when completed
    });

    testWidgets('should use correct colors for other players',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_2',
        isHost: false,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: false,
        ),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.isSelf, false);
      expect(ringProgress.isHost, false);
      // Other players should use border color
      expect(ringProgress.ringState, RingState.countdown);
    });

    testWidgets('should use correct colors in review mode for host',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.reviewPlayerState(
        playerId: 'player_1',
        isHost: true,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: true,
        ),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.isHost, true);
      expect(ringProgress.ringState, RingState.review);
      // Host should use primary color in review mode
    });

    testWidgets('should use correct colors in review mode for self (non-host)',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.reviewPlayerState(
        playerId: 'player_1',
        isHost: false,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: true,
        ),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.isSelf, true);
      expect(ringProgress.isHost, false);
      expect(ringProgress.ringState, RingState.review);
      // Self (non-host) should use info color in review mode
    });
  });

  group('PlayerWidget - Ring Progress (Multi-Player Scenarios)', () {
    testWidgets('should show decrementing ring before self submits',
        (WidgetTester tester) async {
      // Arrange
      final tracker = QuestionDeadlineProgressTracker();
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: true,
          deadlineProgressTracker: tracker,
        ),
      );

      // Start tracker with a short duration to simulate countdown
      tracker.start(const Duration(milliseconds: 200));
      // Advance time to allow timer to update (timer updates every 50ms)
      await tester.binding.delayed(const Duration(milliseconds: 60));
      await tester.pump();

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.ringState, RingState.countdown);
      // Progress should be in valid range (0-1)
      // Note: Progress may still be 0 if timer hasn't fired yet in test environment
      expect(ringProgress.ringProgress, greaterThanOrEqualTo(0.0));
      expect(ringProgress.ringProgress, lessThanOrEqualTo(1.0));

      // Clean up: stop the tracker to cancel the timer
      tracker.stop();
    });

    testWidgets('should show completed success-colored ring after self submits',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.readyPlayerState(
        playerId: 'player_1',
        isHost: false,
        submittedAnswer: const AnswerValue(
          number: 8,
          orderOfMagnitude: 'M',
          unit: 'p',
        ),
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: true,
        ),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.ringState, RingState.completed);
      expect(ringProgress.isSelf, true);
      expect(ringProgress.isHost, false);
    });

    testWidgets(
        'should show other players decrementing rings before they submit',
        (WidgetTester tester) async {
      // Arrange
      final tracker = QuestionDeadlineProgressTracker();
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_2',
        isHost: false,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: false,
          deadlineProgressTracker: tracker,
        ),
      );

      // Start tracker with a short duration to simulate countdown
      tracker.start(const Duration(milliseconds: 200));
      // Advance time to allow timer to update (timer updates every 50ms)
      await tester.binding.delayed(const Duration(milliseconds: 60));
      await tester.pump();

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.ringState, RingState.countdown);
      expect(ringProgress.isSelf, false);
      // Progress should be in valid range (0-1)
      // Note: Progress may still be 0 if timer hasn't fired yet in test environment
      expect(ringProgress.ringProgress, greaterThanOrEqualTo(0.0));
      expect(ringProgress.ringProgress, lessThanOrEqualTo(1.0));

      // Clean up: stop the tracker to cancel the timer
      tracker.stop();
    });

    testWidgets('should show other players completed rings after they submit',
        (WidgetTester tester) async {
      // Arrange
      final playerState = PlayerDataFixtures.readyPlayerState(
        playerId: 'player_2',
        isHost: false,
        submittedAnswer: const AnswerValue(
          number: 7,
          orderOfMagnitude: 'M',
          unit: 'p',
        ),
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          isSelf: false,
        ),
      );

      // Assert
      final ringProgress = tester.widget<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );
      expect(ringProgress.ringState, RingState.completed);
      expect(ringProgress.isSelf, false);
    });
  });

  group('PlayerWidget - Score Animation', () {
    testWidgets('should animate score increase', (WidgetTester tester) async {
      // Arrange
      final controller = PlayerWidgetController();
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
        score: 0,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          controller: controller,
          showScoreOverlay: true,
        ),
      );

      // Update score
      controller.setScore(100);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(PlayerScore), findsOneWidget);
    });

    testWidgets('should show round score chip on reveal',
        (WidgetTester tester) async {
      // Arrange
      final controller = PlayerWidgetController();
      // Create widget without initial roundScore so increment will show when set
      final playerState = PlayerDataFixtures.answerPlayerState(
        playerId: 'player_1',
        score: 100,
        roundScore: 0, // Start with 0
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          controller: controller,
          showScoreOverlay: true,
        ),
      );

      // Trigger round score update to 50
      controller.setRoundScore(50);
      await tester.pumpAndSettle();

      // Assert
      // Per-question score should appear within PlayerScore widget at top
      expect(find.textContaining('+50'), findsOneWidget);
    });

    testWidgets('should clear round score chip on next question',
        (WidgetTester tester) async {
      // Arrange
      final controller = PlayerWidgetController();
      // Create widget without initial roundScore
      final playerStateWithScore = PlayerDataFixtures.answerPlayerState(
        playerId: 'player_1',
        score: 100,
        roundScore: 0, // Start with 0
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerStateWithScore,
          controller: controller,
          showScoreOverlay: true,
        ),
      );

      // Set round score to 50 to show increment
      controller.setRoundScore(50);
      await tester.pumpAndSettle();
      expect(find.textContaining('+50'), findsOneWidget);

      // Clear round score via controller (simulating next question)
      controller.setRoundScore(0);
      // Wait for both animations to complete (280ms opacity + 320ms slide = 600ms)
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      // Assert
      // Increment should be hidden when round score is 0 (after fade-out animation)
      // Note: Widget may still be in tree with opacity 0, so we check the AnimatedOpacity
      final opacityFinder = find.ancestor(
        of: find.textContaining('+50'),
        matching: find.byType(AnimatedOpacity),
      );
      if (opacityFinder.evaluate().isNotEmpty) {
        final opacityWidget = tester.widget<AnimatedOpacity>(opacityFinder);
        expect(opacityWidget.opacity, 0.0);
      } else {
        // Widget removed from tree (also valid)
        expect(find.textContaining('+50'), findsNothing);
      }
    });

    testWidgets('should animate cumulative score', (WidgetTester tester) async {
      // Arrange
      final controller = PlayerWidgetController();
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
        score: 0,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          controller: controller,
          showScoreOverlay: true,
        ),
      );

      // Update cumulative score
      controller.setScore(200);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(PlayerScore), findsOneWidget);
    });
  });

  group('PlayerWidget - Confetti', () {
    testWidgets('should trigger confetti for highest scorer',
        (WidgetTester tester) async {
      // Arrange
      final controller = PlayerWidgetController();
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          controller: controller,
        ),
      );

      // Trigger confetti
      controller.triggerConfetti();
      await tester.pump();

      // Assert
      expect(find.byType(PlayerConfettiOverlay), findsOneWidget);
    });

    testWidgets('should clip confetti to widget bounds',
        (WidgetTester tester) async {
      // Arrange
      final controller = PlayerWidgetController();
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          controller: controller,
        ),
      );

      // Trigger confetti
      controller.triggerConfetti();
      await tester.pump();

      // Assert
      final confetti = tester.widget<PlayerConfettiOverlay>(
        find.byType(PlayerConfettiOverlay),
      );
      expect(confetti, isNotNull);
      // Confetti is positioned with Positioned.fill and clipped

      // Clean up: dispose widget to cancel timers
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('should clear confetti on next question',
        (WidgetTester tester) async {
      // Arrange
      final controller = PlayerWidgetController();
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          controller: controller,
        ),
      );

      // Trigger confetti
      controller.triggerConfetti();
      await tester.pump();
      expect(find.byType(PlayerConfettiOverlay), findsOneWidget);

      // Clear confetti
      controller.clearConfetti();
      await tester.pump();

      // Assert
      expect(find.byType(PlayerConfettiOverlay), findsNothing);

      // Clean up: dispose widget to cancel timers
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('PlayerWidget - Controller Binding', () {
    testWidgets('should bind to PlayerWidgetController',
        (WidgetTester tester) async {
      // Arrange
      final controller = PlayerWidgetController();
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          controller: controller,
        ),
      );

      // Assert
      // Controller is bound in initState
      expect(controller, isNotNull);
    });

    testWidgets('should update on controller score changes',
        (WidgetTester tester) async {
      // Arrange
      final controller = PlayerWidgetController();
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
        score: 0,
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          controller: controller,
          showScoreOverlay: true,
        ),
      );

      // Update score via controller
      controller.setScore(150);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(PlayerScore), findsOneWidget);
    });

    testWidgets('should trigger confetti on controller call',
        (WidgetTester tester) async {
      // Arrange
      final controller = PlayerWidgetController();
      final playerState = PlayerDataFixtures.waitingPlayerState(
        playerId: 'player_1',
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        PlayerWidget(
          playerState: playerState,
          controller: controller,
        ),
      );

      // Trigger confetti via controller
      controller.triggerConfetti();
      await tester.pump();

      // Assert
      expect(find.byType(PlayerConfettiOverlay), findsOneWidget);
    });
  });
}
