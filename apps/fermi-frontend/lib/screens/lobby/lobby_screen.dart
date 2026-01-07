import 'dart:async';

import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/share_button.dart';
import 'package:fermi_frontend/widgets/invite_bots_button.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/players_row.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({
    super.key,
    required this.players,
    required this.onStart,
    this.startEnabled = true,
    this.onShare,
    this.joinUrl,
    this.onLeave,
    this.currentPlayerId,
    this.isHost = false,
    this.onInviteBots,
    this.botsToInvite = 0,
    this.createdAt,
  });

  final List<PlayerState> players;
  final VoidCallback onStart;
  final VoidCallback? onShare;
  final bool startEnabled;
  final String? joinUrl;
  final VoidCallback? onLeave;
  final String? currentPlayerId;
  final bool isHost;
  final VoidCallback? onInviteBots;
  final int botsToInvite;
  final DateTime? createdAt;

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
      child: ResponsiveContainer(
        backgroundColor: appTheme.bgDark,
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
                  Padding(
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
                              isHost: isHost,
                              onStart: onStart,
                              startEnabled: startEnabled,
                              createdAt: createdAt,
                            ),
                          );
                        }),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isHost &&
                                  botsToInvite > 0 &&
                                  onInviteBots != null) ...[
                                InviteBotsButton(
                                  onPressed: onInviteBots!,
                                  botCount: botsToInvite,
                                  iconOnly: true,
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (onShare != null) ...[
                                ShareButton(
                                  onPressed: onShare!,
                                  iconOnly: true,
                                ),
                                const SizedBox(height: 48),
                              ],
                            ],
                          ),
                        ),
                        // Removed Spacer to keep buttons significantly closer to the start button
                        MainButton(
                          onPressed: startEnabled ? onStart : null,
                          label: MainButtonLabel.start,
                          iconAssetPath: 'assets/icons/spacebar.svg',
                        ),
                      ],
                    ),
                  ),
                  LeaveButtonOverlay(
                    iconColor: appTheme.border,
                    splashColor: appTheme.borderMuted,
                    onPressed:
                        onLeave ?? () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterCallout extends StatefulWidget {
  const _CenterCallout({
    this.isHost = false,
    required this.onStart,
    required this.startEnabled,
    this.createdAt,
  });

  final bool isHost;
  final VoidCallback onStart;
  final bool startEnabled;
  final DateTime? createdAt;

  @override
  State<_CenterCallout> createState() => _CenterCalloutState();
}

class _CenterCalloutState extends State<_CenterCallout>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late int _timeLeft;
  late AnimationController _dotsController;
  int _dotCount = 0;

  // 60s for private games (allow friends to join)
  static const int _privateDuration = 60;

  @override
  void initState() {
    super.initState();
    _timeLeft = _computeRemainingTime();
    _startTimer();

    // Animation for "..."
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _dotsController.addListener(() {
      final newCount = (_dotsController.value * 4).floor(); // 0, 1, 2, 3
      if (newCount != _dotCount) {
        setState(() {
          _dotCount = newCount;
        });
      }
    });
  }

  @override
  void didUpdateWidget(_CenterCallout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalculate timer if createdAt changes
    if (widget.createdAt != oldWidget.createdAt) {
      setState(() {
        _timeLeft = _computeRemainingTime();
      });
    }
  }

  /// Compute remaining time from server timestamp to ensure all clients
  /// see the same synchronized timer value.
  int _computeRemainingTime() {
    const int duration = _privateDuration;
    final DateTime? created = widget.createdAt;
    if (created == null) {
      // Fallback to full duration if timestamp not yet available
      return duration;
    }
    final int elapsed = DateTime.now().difference(created).inSeconds;
    return (duration - elapsed).clamp(0, duration);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Recalculate from server timestamp each tick to stay perfectly synced
      final int remaining = _computeRemainingTime();
      if (remaining > 0) {
        setState(() {
          _timeLeft = remaining;
        });
      } else {
        _timer.cancel();
        setState(() {
          _timeLeft = 0;
        });
        // Only host triggers the auto-start
        if (widget.isHost && widget.startEnabled) {
          widget.onStart();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final timerText = Text(
      '$_timeLeft',
      style: TextStyle(
        fontFamily: 'Jura',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: appTheme.text,
      ),
    );

    final autoStartLabel = Text(
      'Auto start in',
      style: TextStyle(
        fontFamily: 'Barlow',
        fontSize: 16,
        color: appTheme.textMuted,
      ),
    );

    // Private lobby: show share button and optionally bot button for host
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          autoStartLabel,
          const SizedBox(height: 4),
          timerText,
        ],
      ),
    );
  }
}
