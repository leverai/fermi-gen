import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/share_button.dart';
import 'package:fermi_frontend/widgets/invite_bots_button.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/players_row.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({
    super.key,
    required this.players,
    required this.isWaiting,
    required this.onStart,
    this.startEnabled = true,
    this.onShare,
    this.isPrivate = false,
    this.joinUrl,
    this.onLeave,
    this.currentPlayerId,
    this.isHost = false,
    this.onInviteBots,
    this.botsToInvite = 0,
  });

  final List<PlayerState> players;
  final bool isWaiting;
  final VoidCallback onStart;
  final VoidCallback? onShare;
  final bool startEnabled;
  final bool isPrivate;
  final String? joinUrl;
  final VoidCallback? onLeave;
  final String? currentPlayerId;
  final bool isHost;
  final VoidCallback? onInviteBots;
  final int botsToInvite;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        // Trigger the same action as the leave button
        if (onLeave != null) {
          onLeave!();
        } else {
          Navigator.of(context).maybePop();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [appTheme.bg, appTheme.bg, appTheme.bgDark],
                stops: const [0.0, 0.8, 1.0],
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 24, right: 24, top: 0, bottom: 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PlayersRow(
                          players: players,
                          alignment: MainAxisAlignment.center,
                          showScoreOverlay: false,
                          showNameChip: true,
                          currentPlayerId: currentPlayerId,
                        ),
                        const Spacer(),
                        Builder(builder: (context) {
                          final Animation<double> anim =
                              ModalRoute.of(context)?.animation ??
                                  const AlwaysStoppedAnimation<double>(1.0);
                          return SlideTransition(
                            position: anim.drive(
                              Tween<Offset>(
                                begin: const Offset(0, 0.25),
                                end: Offset.zero,
                              ).chain(
                                CurveTween(curve: Curves.easeOutCubic),
                              ),
                            ),
                            child: _CenterCallout(
                              isPrivate: isPrivate,
                              isWaiting: isWaiting,
                              onShare: onShare,
                              color: appTheme.info,
                              joinUrl: joinUrl,
                              isHost: isHost,
                              onInviteBots: onInviteBots,
                              botsToInvite: botsToInvite,
                            ),
                          );
                        }),
                        const Spacer(),
                        MainButton(
                          onPressed: startEnabled ? onStart : null,
                          label: MainButtonLabel.start,
                          showSpacebarGlyph: true,
                          iconAssetPath: 'assets/icons/spacebar.svg',
                        ),
                      ],
                    ),
                  ),
                ),
                LeaveButtonOverlay(
                  iconColor: appTheme.borderMuted,
                  splashColor: appTheme.borderMuted,
                  onPressed: onLeave ?? () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterCallout extends StatelessWidget {
  const _CenterCallout({
    required this.isPrivate,
    required this.isWaiting,
    required this.color,
    this.onShare,
    this.joinUrl,
    this.isHost = false,
    this.onInviteBots,
    this.botsToInvite = 0,
  });

  final bool isPrivate;
  final bool isWaiting;
  final Color color;
  final VoidCallback? onShare;
  final String? joinUrl;
  final bool isHost;
  final VoidCallback? onInviteBots;
  final int botsToInvite;

  @override
  Widget build(BuildContext context) {
    // Show bot invitation button if host and bots can be invited
    final showBotButton = isHost && botsToInvite > 0 && onInviteBots != null;

    if (isPrivate) {
      // Private lobby: show share button and optionally bot button for host
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBotButton) ...[
              InviteBotsButton(
                onPressed: onInviteBots!,
                botCount: botsToInvite,
              ),
              const SizedBox(height: 12),
            ],
            ShareButton(onPressed: onShare ?? () {}),
          ],
        ),
      );
    }
    if (isWaiting) {
      // Public lobby waiting: show loading spinner and optionally bot button for host
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBotButton) ...[
              InviteBotsButton(
                onPressed: onInviteBots!,
                botCount: botsToInvite,
              ),
              const SizedBox(height: 12),
            ],
            LoadingAnimationWidget.fourRotatingDots(
              color: color,
              size: 44,
            ),
          ],
        ),
      );
    }
    return const SizedBox(height: 36);
  }
}
