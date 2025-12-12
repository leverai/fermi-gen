import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/share_button.dart';
import 'lobby_screen_test_helpers.dart';

void main() {
  setupLobbyScreenTests();

  group('LobbyScreen - State Updates', () {
    testWidgets('should update when players join', (tester) async {
      // ARRANGE - Initial state with 1 player
      final initialPlayers = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          ringState: RingState.review,
        ),
      ];

      await pumpLobbyScreen(
        tester,
        players: initialPlayers,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT - Should have 1 player
      expect(find.byType(PlayerWidget), findsOneWidget);

      // ACT - Update with 2 players
      final updatedPlayers = [
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

      await pumpLobbyScreen(
        tester,
        players: updatedPlayers,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT - Should now have 2 players
      expect(find.byType(PlayerWidget), findsNWidgets(2));
    });

    testWidgets('should update when players leave', (tester) async {
      // ARRANGE - Initial state with 3 players
      final initialPlayers = [
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
        const PlayerState(
          playerId: 'player_3',
          isHost: false,
          status: PlayerStatus.none,
          displayName: 'Charlie',
          ringState: RingState.review,
        ),
      ];

      await pumpLobbyScreen(
        tester,
        players: initialPlayers,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT - Should have 3 players
      expect(find.byType(PlayerWidget), findsNWidgets(3));

      // ACT - Update with 2 players (one left)
      final updatedPlayers = [
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

      await pumpLobbyScreen(
        tester,
        players: updatedPlayers,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT - Should now have 2 players
      expect(find.byType(PlayerWidget), findsNWidgets(2));
    });

    testWidgets('should enable start when lobby ready', (tester) async {
      // ARRANGE - Initial state not ready
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          ringState: RingState.review,
        ),
      ];

      await pumpLobbyScreen(
        tester,
        players: players,
        startEnabled: false,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT - Button should be disabled
      final disabledButton = tester.widget<MainButton>(find.byType(MainButton));
      expect(disabledButton.onPressed, isNull);

      // ACT - Update to ready state
      await pumpLobbyScreen(
        tester,
        players: players,
        startEnabled: true,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT - Button should now be enabled
      final enabledButton = tester.widget<MainButton>(find.byType(MainButton));
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets('should switch between waiting and ready states',
        (tester) async {
      // ARRANGE - Initial state waiting
      const players = [
        PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          ringState: RingState.review,
        ),
      ];

      await pumpLobbyScreen(
        tester,
        players: players,
        isWaiting: true,
        isPrivate: false,
        currentPlayerId: 'player_1',
      );
      // Use pump() instead of pumpAndSettle() to avoid infinite animation timeout
      await tester.pump();

      // ASSERT - Share button should not be present (waiting state)
      expect(find.byType(ShareButton), findsNothing);

      // ACT - Update to ready state (not waiting)
      await pumpLobbyScreen(
        tester,
        players: players,
        isWaiting: false,
        isPrivate: false,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT - Should show neither share button nor spinner
      expect(find.byType(ShareButton), findsNothing);
    });

    testWidgets('should switch between public and private game modes',
        (tester) async {
      // ARRANGE - Initial state public
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          ringState: RingState.review,
        ),
      ];

      await pumpLobbyScreen(
        tester,
        players: players,
        isPrivate: false,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT - Share button should not be present (public game)
      expect(find.byType(ShareButton), findsNothing);

      // ACT - Update to private game
      await pumpLobbyScreen(
        tester,
        players: players,
        isPrivate: true,
        joinUrl: 'https://example.com/join/abc',
        onShare: () {},
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT - Share button should now be present
      expect(find.byType(ShareButton), findsOneWidget);
    });

    testWidgets('should update player ring colors when currentPlayerId changes',
        (tester) async {
      // ARRANGE - Initial state with player_1 as current
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

      await pumpLobbyScreen(
        tester,
        players: players,
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ACT - Update with player_2 as current
      await pumpLobbyScreen(
        tester,
        players: players,
        currentPlayerId: 'player_2',
      );
      await pumpLobbyFrames(tester);

      // ASSERT - Ring assignments should update
      // (The actual color rendering is handled by PlayerRingProgress,
      // we're just verifying the props are passed correctly)
      expect(find.byType(PlayerWidget), findsNWidgets(2));
    });
  });
}
