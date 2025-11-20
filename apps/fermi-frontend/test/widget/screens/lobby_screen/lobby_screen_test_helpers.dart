import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/screens/lobby/lobby_screen.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import '../../../helpers/test_helpers.dart';
import '../../../helpers/mock_factories.dart';

/// Shared test setup for LobbyScreen widget tests
void setupLobbyScreenTests() {
  setUpAll(() {
    registerFallbackValues();
  });
}

/// Helper to create a list of PlayerState objects from a snapshot
List<PlayerState> createPlayerStatesFromSnapshot(GameSnapshot snapshot) {
  return snapshot.players.values
      .map((p) => PlayerState(
            playerId: p.playerId,
            isHost: p.isHost,
            status: PlayerStatus.none,
            score: p.score.round(),
            avatarUrl: p.pictureUrl,
            displayName: p.name,
            ringState: RingState.review, // Static ring in lobby
          ))
      .toList(growable: false);
}

/// Helper to pump LobbyScreen with default test setup
Future<void> pumpLobbyScreen(
  WidgetTester tester, {
  required List<PlayerState> players,
  bool isWaiting = false,
  VoidCallback? onStart,
  bool startEnabled = true,
  VoidCallback? onShare,
  bool isPrivate = false,
  String? joinUrl,
  VoidCallback? onLeave,
  String? currentPlayerId,
}) async {
  await pumpWithMaterialApp(
    tester,
    LobbyScreen(
      players: players,
      isWaiting: isWaiting,
      onStart: onStart ?? () {},
      startEnabled: startEnabled,
      onShare: onShare,
      isPrivate: isPrivate,
      joinUrl: joinUrl,
      onLeave: onLeave,
      currentPlayerId: currentPlayerId,
    ),
  );
}
