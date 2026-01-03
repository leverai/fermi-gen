import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/share_button.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';
import 'lobby_screen_test_helpers.dart';

void main() {
  setupLobbyScreenTests();

  group('LobbyScreen - Actions', () {
    testWidgets('should call onStart when start button tapped', (tester) async {
      // ARRANGE
      bool startCalled = false;
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
        onStart: () {
          startCalled = true;
        },
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      await tester.tap(find.byType(MainButton));
      await pumpLobbyFrames(tester);

      // ASSERT
      expect(startCalled, isTrue);
    });

    testWidgets('should call onShare when share button tapped', (tester) async {
      // ARRANGE
      bool shareCalled = false;
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
        onShare: () {
          shareCalled = true;
        },
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      await tester.tap(find.byType(ShareButton));
      await pumpLobbyFrames(tester);

      // ASSERT
      expect(shareCalled, isTrue);
    });

    testWidgets('should not call onShare when share button not provided',
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
        onShare: null, // No share handler
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT
      // ShareButton should NOT be rendered when onShare is null
      expect(find.byType(ShareButton), findsNothing);
    });

    testWidgets('should call onLeave when leave button tapped', (tester) async {
      // ARRANGE
      bool leaveCalled = false;
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
        onLeave: () {
          leaveCalled = true;
        },
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // Find the leave button (it's an IconButton inside LeaveButtonOverlay)
      await tester.tap(find.byType(IconButton));
      await pumpLobbyFrames(tester);

      // ASSERT
      expect(leaveCalled, isTrue);
    });

    testWidgets('should handle back navigation with onLeave', (tester) async {
      // ARRANGE
      bool leaveCalled = false;
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
        onLeave: () {
          leaveCalled = true;
        },
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // Simulate back button press
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await pumpLobbyFrames(tester);

      // ASSERT
      // onLeave should be called via PopScope's onPopInvokedWithResult
      expect(leaveCalled, isTrue);
    });

    testWidgets('should not crash when onLeave is null', (tester) async {
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
        onLeave: null, // No leave handler
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // ASSERT
      // Should not crash, LeaveButtonOverlay should use Navigator.maybePop fallback
      expect(find.byType(LeaveButtonOverlay), findsOneWidget);
    });

    testWidgets('should not allow start when button is disabled',
        (tester) async {
      // ARRANGE
      bool startCalled = false;
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
        startEnabled: false, // Button disabled
        onStart: () {
          startCalled = true;
        },
        currentPlayerId: 'player_1',
      );
      await pumpLobbyFrames(tester);

      // Try to tap the disabled button
      await tester.tap(find.byType(MainButton));
      await pumpLobbyFrames(tester);

      // ASSERT
      // onStart should not be called because button is disabled
      expect(startCalled, isFalse);
    });
  });
}
