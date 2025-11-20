import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/player_ring_progress.dart';
import 'package:fermi_frontend/widgets/players_row.dart';
import 'lobby_screen_test_helpers.dart';

void main() {
  setupLobbyScreenTests();

  group('LobbyScreen - Player Display', () {
    testWidgets('should show player avatars', (tester) async {
      // ARRANGE
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          avatarUrl: null, // Use null to avoid network requests in tests
          ringState: RingState.review,
        ),
        const PlayerState(
          playerId: 'player_2',
          isHost: false,
          status: PlayerStatus.none,
          displayName: 'Bob',
          avatarUrl: null, // Use null to avoid network requests in tests
          ringState: RingState.review,
        ),
      ];

      // ACT
      await pumpLobbyScreen(
        tester,
        players: players,
        currentPlayerId: 'player_1',
      );
      await tester.pumpAndSettle();

      // ASSERT
      // PlayerWidgets are rendered (avatars are inside)
      expect(find.byType(PlayerWidget), findsNWidgets(2));
    });

    testWidgets('should show player names when name chip enabled',
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
      await tester.pumpAndSettle();

      // ASSERT
      // PlayersRow is configured with showNameChip: true in LobbyScreen
      final playersRow = tester.widget<PlayersRow>(find.byType(PlayersRow));
      expect(playersRow.showNameChip, isTrue);

      // Tap a player to show name (names are initially hidden, shown on tap)
      await tester.tap(find.byType(PlayerWidget).first);
      await tester.pumpAndSettle();

      // Name should now be visible
      expect(find.text('Alice'), findsOneWidget);

      // Clean up: dispose widget and elapse time to let TextScroll timers complete
      // TextScroll creates a timer with delayBefore: 1s that isn't canceled in dispose
      // We need to elapse time in the fake async context to let the timer complete
      await tester.pumpWidget(const SizedBox());
      // Elapse time to let the pending timer (1 second delayBefore) complete
      // Use binding.delayed to advance fake async time
      await tester.binding.delayed(const Duration(seconds: 2));
      await tester.pump();
    });

    testWidgets('should highlight host with gold ring color', (tester) async {
      // ARRANGE
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice (Host)',
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
        currentPlayerId: 'player_2', // Current player is NOT the host
      );
      await tester.pumpAndSettle();

      // ASSERT
      // Find all PlayerRingProgress widgets
      final ringWidgets = tester.widgetList<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );

      expect(ringWidgets.length, 2);

      // First player (host) should have isHost: true
      final hostRing = ringWidgets.first;
      expect(hostRing.isHost, isTrue);
      expect(hostRing.isSelf, isFalse);
      expect(hostRing.ringState, RingState.review);

      // Second player (not host) should have isHost: false
      final otherRing = ringWidgets.last;
      expect(otherRing.isHost, isFalse);
      expect(otherRing.isSelf, isTrue); // Current player
      expect(otherRing.ringState, RingState.review);
    });

    testWidgets('should highlight current player with self ring color',
        (tester) async {
      // ARRANGE
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice (Host)',
          ringState: RingState.review,
        ),
        const PlayerState(
          playerId: 'player_2',
          isHost: false,
          status: PlayerStatus.none,
          displayName: 'Bob (Self)',
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

      // ACT
      await pumpLobbyScreen(
        tester,
        players: players,
        currentPlayerId: 'player_2', // Bob is the current player (self)
      );
      await tester.pumpAndSettle();

      // ASSERT
      // Find all PlayerRingProgress widgets
      final ringWidgets = tester.widgetList<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );

      expect(ringWidgets.length, 3);

      final rings = ringWidgets.toList();

      // Player 1 (host, not self)
      expect(rings[0].isHost, isTrue);
      expect(rings[0].isSelf, isFalse);

      // Player 2 (not host, is self)
      expect(rings[1].isHost, isFalse);
      expect(rings[1].isSelf, isTrue);

      // Player 3 (not host, not self)
      expect(rings[2].isHost, isFalse);
      expect(rings[2].isSelf, isFalse);
    });

    testWidgets('should show host ring when current player is host',
        (tester) async {
      // ARRANGE
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice (Host & Self)',
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
        currentPlayerId: 'player_1', // Current player IS the host
      );
      await tester.pumpAndSettle();

      // ASSERT
      // Find all PlayerRingProgress widgets
      final ringWidgets = tester.widgetList<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );

      expect(ringWidgets.length, 2);

      final rings = ringWidgets.toList();

      // Player 1 (host AND self) - host ring takes precedence
      expect(rings[0].isHost, isTrue);
      expect(rings[0].isSelf, isTrue);

      // Player 2 (not host, not self)
      expect(rings[1].isHost, isFalse);
      expect(rings[1].isSelf, isFalse);
    });

    testWidgets('should use review ring state in lobby for all players',
        (tester) async {
      // ARRANGE
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice',
          ringState: RingState.review, // Static ring in lobby
        ),
        const PlayerState(
          playerId: 'player_2',
          isHost: false,
          status: PlayerStatus.none,
          displayName: 'Bob',
          ringState: RingState.review, // Static ring in lobby
        ),
      ];

      // ACT
      await pumpLobbyScreen(
        tester,
        players: players,
        currentPlayerId: 'player_1',
      );
      await tester.pumpAndSettle();

      // ASSERT
      // All players should have review ring state
      final ringWidgets = tester.widgetList<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );

      for (final ring in ringWidgets) {
        expect(ring.ringState, RingState.review);
      }
    });

    testWidgets(
        'should display other player with border ring when not self and not host',
        (tester) async {
      // ARRANGE
      final players = [
        const PlayerState(
          playerId: 'player_1',
          isHost: true,
          status: PlayerStatus.none,
          displayName: 'Alice (Host)',
          ringState: RingState.review,
        ),
        const PlayerState(
          playerId: 'player_2',
          isHost: false,
          status: PlayerStatus.none,
          displayName: 'Bob (Self)',
          ringState: RingState.review,
        ),
        const PlayerState(
          playerId: 'player_3',
          isHost: false,
          status: PlayerStatus.none,
          displayName: 'Charlie (Other)',
          ringState: RingState.review,
        ),
      ];

      // ACT
      await pumpLobbyScreen(
        tester,
        players: players,
        currentPlayerId: 'player_2',
      );
      await tester.pumpAndSettle();

      // ASSERT
      final ringWidgets = tester.widgetList<PlayerRingProgress>(
        find.byType(PlayerRingProgress),
      );

      final rings = ringWidgets.toList();

      // Player 3 (other) should have both flags false
      expect(rings[2].isHost, isFalse);
      expect(rings[2].isSelf, isFalse);
      expect(rings[2].ringState, RingState.review);
    });
  });
}
