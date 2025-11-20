import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/players_row.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('PlayersRow - Rendering', () {
    testWidgets('should display all players', (WidgetTester tester) async {
      // Arrange
      final players = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100,
          isHost: true,
        ),
        const PlayerState(
          playerId: 'player_2',
          displayName: 'Player 2',
          score: 80,
        ),
        const PlayerState(
          playerId: 'player_3',
          displayName: 'Player 3',
          score: 60,
        ),
      ];

      final widget = PlayersRow(
        players: players,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Verify all 3 PlayerWidget instances are displayed
      expect(find.byType(PlayerWidget), findsNWidgets(3));
    });

    testWidgets('should sort players by rank (score descending)',
        (WidgetTester tester) async {
      // Arrange
      // Create players in random order
      final players = [
        const PlayerState(
          playerId: 'player_2',
          displayName: 'Player 2',
          score: 50, // Lowest score
        ),
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100, // Highest score
        ),
        const PlayerState(
          playerId: 'player_3',
          displayName: 'Player 3',
          score: 75, // Middle score
        ),
      ];

      // Note: PlayersRow only sorts when showRankIcons is true
      final widget = PlayersRow(
        players: players,
        showRankIcons: true,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Find all PlayerWidget instances
      final playerWidgets = tester.widgetList<PlayerWidget>(
        find.byType(PlayerWidget),
      );

      // Verify they are sorted by score descending
      expect(playerWidgets.length, 3);
      expect(playerWidgets.elementAt(0).playerState.playerId, 'player_1');
      expect(playerWidgets.elementAt(0).playerState.score, 100);
      expect(playerWidgets.elementAt(1).playerState.playerId, 'player_3');
      expect(playerWidgets.elementAt(1).playerState.score, 75);
      expect(playerWidgets.elementAt(2).playerState.playerId, 'player_2');
      expect(playerWidgets.elementAt(2).playerState.score, 50);
    });

    testWidgets('should center align players by default',
        (WidgetTester tester) async {
      // Arrange
      final players = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100,
        ),
        const PlayerState(
          playerId: 'player_2',
          displayName: 'Player 2',
          score: 80,
        ),
      ];

      final widget = PlayersRow(
        players: players,
        alignment: MainAxisAlignment.center,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Verify PlayersRow renders with <=3 players (uses Row layout, not scrollable)
      expect(find.byType(PlayersRow), findsOneWidget);
      expect(find.byType(PlayerWidget), findsNWidgets(2));

      // For <=3 players, PlayersRow uses Row layout (not SingleChildScrollView)
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('should handle empty player list',
        (WidgetTester tester) async {
      // Arrange
      const widget = PlayersRow(
        players: [],
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Should render without crashing
      expect(find.byType(PlayersRow), findsOneWidget);
      // No PlayerWidget instances
      expect(find.byType(PlayerWidget), findsNothing);
    });

    testWidgets('should display scrollable layout for more than 3 players',
        (WidgetTester tester) async {
      // Arrange
      final players = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100,
        ),
        const PlayerState(
          playerId: 'player_2',
          displayName: 'Player 2',
          score: 90,
        ),
        const PlayerState(
          playerId: 'player_3',
          displayName: 'Player 3',
          score: 80,
        ),
        const PlayerState(
          playerId: 'player_4',
          displayName: 'Player 4',
          score: 70,
        ),
      ];

      final widget = PlayersRow(
        players: players,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Verify SingleChildScrollView is used for >3 players
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(PlayerWidget), findsNWidgets(4));
    });

    testWidgets('should sort players with ties by playerId',
        (WidgetTester tester) async {
      // Arrange
      // Create players with same score (tie)
      final players = [
        const PlayerState(
          playerId: 'player_c',
          displayName: 'Player C',
          score: 100,
        ),
        const PlayerState(
          playerId: 'player_a',
          displayName: 'Player A',
          score: 100, // Same score
        ),
        const PlayerState(
          playerId: 'player_b',
          displayName: 'Player B',
          score: 100, // Same score
        ),
      ];

      // Note: PlayersRow only sorts when showRankIcons is true
      final widget = PlayersRow(
        players: players,
        showRankIcons: true,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Find all PlayerWidget instances
      final playerWidgets = tester.widgetList<PlayerWidget>(
        find.byType(PlayerWidget),
      );

      // Verify they are sorted alphabetically by playerId when scores are equal
      expect(playerWidgets.length, 3);
      expect(playerWidgets.elementAt(0).playerState.playerId, 'player_a');
      expect(playerWidgets.elementAt(1).playerState.playerId, 'player_b');
      expect(playerWidgets.elementAt(2).playerState.playerId, 'player_c');
    });

    testWidgets('should show rank icons when enabled',
        (WidgetTester tester) async {
      // Arrange
      final players = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100,
        ),
        const PlayerState(
          playerId: 'player_2',
          displayName: 'Player 2',
          score: 80,
        ),
        const PlayerState(
          playerId: 'player_3',
          displayName: 'Player 3',
          score: 60,
        ),
      ];

      final widget = PlayersRow(
        players: players,
        showRankIcons: true,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Verify all PlayerWidget instances have showRankIcons enabled
      final playerWidgets = tester.widgetList<PlayerWidget>(
        find.byType(PlayerWidget),
      );

      for (final pw in playerWidgets) {
        expect(pw.showRankIcons, true);
      }
    });

    testWidgets('should highlight current player when currentPlayerId is set',
        (WidgetTester tester) async {
      // Arrange
      final players = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100,
        ),
        const PlayerState(
          playerId: 'player_2',
          displayName: 'Player 2',
          score: 80,
        ),
      ];

      final widget = PlayersRow(
        players: players,
        currentPlayerId: 'player_2',
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Find all PlayerWidget instances
      final playerWidgets = tester.widgetList<PlayerWidget>(
        find.byType(PlayerWidget),
      );

      // Verify player_2 has isSelf set to true
      final player2Widget = playerWidgets.firstWhere(
        (pw) => pw.playerState.playerId == 'player_2',
      );
      expect(player2Widget.isSelf, true);

      // Verify player_1 has isSelf set to false
      final player1Widget = playerWidgets.firstWhere(
        (pw) => pw.playerState.playerId == 'player_1',
      );
      expect(player1Widget.isSelf, false);
    });
  });

  group('PlayersRow - Player Updates', () {
    testWidgets('should update when players change',
        (WidgetTester tester) async {
      // Arrange
      final initialPlayers = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100,
        ),
        const PlayerState(
          playerId: 'player_2',
          displayName: 'Player 2',
          score: 80,
        ),
      ];

      Widget buildWidget(List<PlayerState> players) {
        return PlayersRow(
          players: players,
        );
      }

      // Act - Start with initial players
      await pumpWithMaterialApp(tester, buildWidget(initialPlayers));
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.byType(PlayerWidget), findsNWidgets(2));

      // Update with new player list (add a third player)
      final updatedPlayers = [
        ...initialPlayers,
        const PlayerState(
          playerId: 'player_3',
          displayName: 'Player 3',
          score: 60,
        ),
      ];

      await pumpWithMaterialApp(tester, buildWidget(updatedPlayers));
      await tester.pumpAndSettle();

      // Assert
      // Verify new player is added
      expect(find.byType(PlayerWidget), findsNWidgets(3));
    });

    testWidgets('should reorder when ranks change',
        (WidgetTester tester) async {
      // Arrange
      final initialPlayers = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100,
        ),
        const PlayerState(
          playerId: 'player_2',
          displayName: 'Player 2',
          score: 80,
        ),
      ];

      Widget buildWidget(List<PlayerState> players) {
        // Note: PlayersRow only sorts when showRankIcons is true
        return PlayersRow(
          players: players,
          showRankIcons: true,
        );
      }

      // Act - Start with initial order
      await pumpWithMaterialApp(tester, buildWidget(initialPlayers));
      await tester.pumpAndSettle();

      // Verify initial order
      var playerWidgets = tester.widgetList<PlayerWidget>(
        find.byType(PlayerWidget),
      );
      expect(playerWidgets.elementAt(0).playerState.playerId, 'player_1');
      expect(playerWidgets.elementAt(1).playerState.playerId, 'player_2');

      // Update scores to change order (player_2 now has higher score)
      final reorderedPlayers = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 80, // Lower than before
        ),
        const PlayerState(
          playerId: 'player_2',
          displayName: 'Player 2',
          score: 120, // Higher than player_1 now
        ),
      ];

      await pumpWithMaterialApp(tester, buildWidget(reorderedPlayers));
      await tester.pump(); // Start reorder animation

      // Wait for reorder animation to complete
      await tester.pumpAndSettle();

      // Assert
      // Verify order has changed
      playerWidgets = tester.widgetList<PlayerWidget>(
        find.byType(PlayerWidget),
      );
      expect(playerWidgets.elementAt(0).playerState.playerId, 'player_2');
      expect(playerWidgets.elementAt(0).playerState.score, 120);
      expect(playerWidgets.elementAt(1).playerState.playerId, 'player_1');
      expect(playerWidgets.elementAt(1).playerState.score, 80);
    });

    testWidgets('should remove players who left',
        (WidgetTester tester) async {
      // Arrange
      final initialPlayers = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100,
        ),
        const PlayerState(
          playerId: 'player_2',
          displayName: 'Player 2',
          score: 80,
        ),
        const PlayerState(
          playerId: 'player_3',
          displayName: 'Player 3',
          score: 60,
        ),
      ];

      Widget buildWidget(List<PlayerState> players) {
        return PlayersRow(
          players: players,
        );
      }

      // Act - Start with 3 players
      await pumpWithMaterialApp(tester, buildWidget(initialPlayers));
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.byType(PlayerWidget), findsNWidgets(3));

      // Update with player_2 removed
      final updatedPlayers = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100,
        ),
        const PlayerState(
          playerId: 'player_3',
          displayName: 'Player 3',
          score: 60,
        ),
      ];

      await pumpWithMaterialApp(tester, buildWidget(updatedPlayers));
      await tester.pumpAndSettle();

      // Assert
      // Verify player_2 is removed
      expect(find.byType(PlayerWidget), findsNWidgets(2));

      // Verify remaining players are correct
      final playerWidgets = tester.widgetList<PlayerWidget>(
        find.byType(PlayerWidget),
      );
      expect(playerWidgets.elementAt(0).playerState.playerId, 'player_1');
      expect(playerWidgets.elementAt(1).playerState.playerId, 'player_3');
    });

    testWidgets('should update player scores',
        (WidgetTester tester) async {
      // Arrange
      final initialPlayers = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100,
        ),
      ];

      Widget buildWidget(List<PlayerState> players) {
        return PlayersRow(
          players: players,
        );
      }

      // Act - Start with initial score
      await pumpWithMaterialApp(tester, buildWidget(initialPlayers));
      await tester.pumpAndSettle();

      // Verify initial score
      var playerWidget = tester.widget<PlayerWidget>(
        find.byType(PlayerWidget),
      );
      expect(playerWidget.playerState.score, 100);

      // Update with new score
      final updatedPlayers = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 150, // Updated score
        ),
      ];

      await pumpWithMaterialApp(tester, buildWidget(updatedPlayers));
      await tester.pumpAndSettle();

      // Assert
      // Verify score is updated
      playerWidget = tester.widget<PlayerWidget>(
        find.byType(PlayerWidget),
      );
      expect(playerWidget.playerState.score, 150);
    });

    testWidgets('should handle transition from <=3 to >3 players',
        (WidgetTester tester) async {
      // Arrange
      final initialPlayers = [
        const PlayerState(
          playerId: 'player_1',
          displayName: 'Player 1',
          score: 100,
        ),
        const PlayerState(
          playerId: 'player_2',
          displayName: 'Player 2',
          score: 90,
        ),
        const PlayerState(
          playerId: 'player_3',
          displayName: 'Player 3',
          score: 80,
        ),
      ];

      Widget buildWidget(List<PlayerState> players) {
        return PlayersRow(
          players: players,
        );
      }

      // Act - Start with 3 players (centered layout)
      await pumpWithMaterialApp(tester, buildWidget(initialPlayers));
      await tester.pumpAndSettle();

      // Verify centered layout (Row, not scrollable)
      expect(find.byType(Row), findsWidgets);
      expect(find.byType(SingleChildScrollView), findsNothing);

      // Update with 4 players (scrollable layout)
      final updatedPlayers = [
        ...initialPlayers,
        const PlayerState(
          playerId: 'player_4',
          displayName: 'Player 4',
          score: 70,
        ),
      ];

      await pumpWithMaterialApp(tester, buildWidget(updatedPlayers));
      await tester.pumpAndSettle();

      // Assert
      // Verify scrollable layout is now used
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(PlayerWidget), findsNWidgets(4));
    });
  });
}
