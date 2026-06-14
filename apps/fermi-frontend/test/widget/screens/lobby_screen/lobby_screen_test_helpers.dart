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
  VoidCallback? onStart,
  bool startEnabled = true,
  bool isStarting = false,
  VoidCallback? onShare,
  String? joinUrl,
  VoidCallback? onLeave,
  String? currentPlayerId,
}) async {
  await pumpWithMaterialApp(
    tester,
    LobbyScreen(
      players: players,
      onStart: onStart ?? () {},
      startEnabled: startEnabled,
      isStarting: isStarting,
      onShare: onShare,
      joinUrl: joinUrl,
      onLeave: onLeave,
      currentPlayerId: currentPlayerId,
    ),
  );
}

/// Helper to settle animations in lobby screen tests.
/// Uses pump() with duration instead of pumpAndSettle() because:
/// - _CenterCallout has a repeating dots animation (AnimationController.repeat())
/// - _CenterCallout has a periodic timer for auto-start countdown
/// Both never complete, causing pumpAndSettle() to timeout.
Future<void> pumpLobbyFrames(WidgetTester tester, {int frames = 5}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
