import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/players_row.dart';

class TopBarLockAvatar extends StatelessWidget {
  const TopBarLockAvatar({
    super.key,
    this.avatarUrl,
    this.displayName,
  });
  final String? avatarUrl;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: Builder(builder: (context) {
          final double screenW = MediaQuery.of(context).size.width;
          final double headerW =
              math.max(0, math.min(420, screenW - 40)).floorToDouble();
          return SizedBox(
            width: headerW,
                child: PlayersRow(
                  players: [
                    PlayerState(
                      isHost: false,
                      status: PlayerStatus.none,
                      avatarUrl: avatarUrl,
                      displayName: displayName,
                      playerId: 'main-screen-user',
                    ),
                  ],
                  alignment: MainAxisAlignment.center,
                  showScoreOverlay: false,
                  showNameChip: true,
                  currentPlayerId:
                      'main-screen-user', // Always show self-ring in main screen
            ),
          );
        }),
      ),
    );
  }
}
