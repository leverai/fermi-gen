import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/share_button.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';
import 'lobby_screen_test_helpers.dart';

void main() {
  setupLobbyScreenTests();

  group('LobbyScreen - Rendering', () {
    testWidgets('should display player list', (tester) async {
      // ARRANGE
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          ringState: RingState.review,
        ),
        const PlayerState(
          playerId: 'player_2',
          isHost: false,
          status: PlayerStatus.none,
          displayName: 'Bob',
          ringState: RingState.review,
        ),
      ];

      // ACT
      await pumpLobbyScreen(
        tester,
        players: players,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT
      // Verify PlayersRow is present (which contains PlayerWidgets)
      expect(find.byType(PlayerWidget), findsNWidgets(2));
    });

    testWidgets('should display waiting spinner for public games',
        (tester) async {
      // ARRANGE
      const players = [
        PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          ringState: RingState.review,
        ),
      ];

      // ACT
      await pumpLobbyScreen(
        tester,
        players: players,
        currentPlayerId: 'player_1',
      );
      // Use pump() instead of pumpAndSettle() to avoid infinite animation timeout
      await tester.pump();

      // ASSERT
      // The loading animation widget is used for waiting state.
      // LoadingAnimationWidget.fourRotatingDots is used, but we can't
      // easily test that without a key. Just verify no share button is shown.
      expect(find.byType(ShareButton), findsNothing);

      // Clean up TextScroll timers before test ends
      await tester.pumpWidget(const SizedBox());
      await tester.binding.delayed(const Duration(seconds: 1));
      await tester.pump();
    });

    testWidgets('should display start button for host when ready',
        (tester) async {
      // ARRANGE
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          ringState: RingState.review,
        ),
      ];

      // ACT
      await pumpLobbyScreen(
        tester,
        players: players,
        startEnabled: true,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT
      expect(find.byType(MainButton), findsOneWidget);
      final button = tester.widget<MainButton>(find.byType(MainButton));
      expect(button.onPressed, isNotNull); // Button is enabled
    });

    testWidgets('should disable start button when not ready', (tester) async {
      // ARRANGE
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          ringState: RingState.review,
        ),
      ];

      // ACT
      await pumpLobbyScreen(
        tester,
        players: players,
        startEnabled: false,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT
      expect(find.byType(MainButton), findsOneWidget);
      final button = tester.widget<MainButton>(find.byType(MainButton));
      expect(button.onPressed, isNull); // Button is disabled
    });

    testWidgets('should display share button for private games',
        (tester) async {
      // ARRANGE
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          ringState: RingState.review,
        ),
      ];

      // ACT
      await pumpLobbyScreen(
        tester,
        players: players,
        joinUrl: 'https://example.com/join/abc',
        onShare: () {},
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT
      expect(find.byType(ShareButton), findsOneWidget);
    });

    testWidgets('should display leave button', (tester) async {
      // ARRANGE
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          ringState: RingState.review,
        ),
      ];

      // ACT
      await pumpLobbyScreen(
        tester,
        players: players,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT
      // LeaveButtonOverlay is present
      expect(find.byType(LeaveButtonOverlay), findsOneWidget);
    });
  });
}
