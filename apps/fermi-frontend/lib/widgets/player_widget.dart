import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/theme/colormap.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:text_scroll/text_scroll.dart';
import 'player_score.dart';
import 'player_score_controller.dart';
import 'player_widget_controller.dart';
import 'rank_widget.dart';
import 'answer_score_card.dart';
import 'player_confetti_overlay.dart';
import 'player_ring_progress.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'question_deadline_progress_tracker.dart';

enum PlayerStatus { waiting, ready, number, answer, none }

/// Ring state for player avatar progress indicator
enum RingState {
  countdown, // Answer phase: 100→0 progress
  completed, // Player answered: Static 100%, success color
  review, // Review mode: Static 100%, colored by ring type
}

class PlayerState {
  final bool isHost;
  final PlayerStatus status;
  final int? score;
  final int? roundScore;
  final String? avatarUrl;
  final AnswerValue? submittedAnswer;
  final String? playerId;
  final String? displayName;
  final RingState ringState;

  const PlayerState({
    this.isHost = false,
    this.status = PlayerStatus.none,
    this.score,
    this.roundScore,
    this.avatarUrl,
    this.submittedAnswer,
    this.playerId,
    this.displayName,
    this.ringState = RingState.countdown,
  });

  PlayerState copyWith({
    bool? isHost,
    PlayerStatus? status,
    int? score,
    int? roundScore,
    String? avatarUrl,
    AnswerValue? submittedAnswer,
    String? playerId,
    String? displayName,
    RingState? ringState,
  }) {
    return PlayerState(
      isHost: isHost ?? this.isHost,
      status: status ?? this.status,
      score: score ?? this.score,
      roundScore: roundScore ?? this.roundScore,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      submittedAnswer: submittedAnswer ?? this.submittedAnswer,
      playerId: playerId ?? this.playerId,
      displayName: displayName ?? this.displayName,
      ringState: ringState ?? this.ringState,
    );
  }
}

class PlayerWidget extends StatefulWidget {
  const PlayerWidget({
    super.key,
    required this.playerState,
    this.showScoreOverlay = true,
    this.animateScoreOverlay = true,
    this.controller,
    this.showNameChip = false,
    this.showRankIcons = false,
    this.rankOverride,
    this.rankAnimationStyle = RankAnimationStyle.none,
    this.isSelf = false,
    this.deadlineProgressTracker,
  });

  final PlayerState playerState;
  final bool showScoreOverlay;
  final bool animateScoreOverlay;
  final PlayerWidgetController? controller;
  final bool showNameChip;

  /// When true, the medal is displayed based on [rankOverride]. Typically true
  /// only at end of game. While false, space is reserved to avoid layout shift.
  final bool showRankIcons;

  /// Overrides medal selection for this widget. Convention: by display order
  /// (0=gold, 1=silver, 2=bronze). Ignored when [showRankIcons] is false.
  final Rank? rankOverride;

  /// Selects the animation style used by the rank icon when shown.
  final RankAnimationStyle rankAnimationStyle;

  /// When true, shows a ring around the avatar using the theme's info color.
  /// When false, shows a ring using the theme's border color.
  /// Host status is indicated separately via the ring gap color (primary for host).
  final bool isSelf;

  /// Notifier for deadline progress
  final QuestionDeadlineProgressTracker? deadlineProgressTracker;

  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  final PlayerScoreController _scoreOverlayController = PlayerScoreController();
  final PlayerScoreController _statusScoreController = PlayerScoreController();
  late int _currentScore;
  late int _currentRoundScore;
  int? _lastIncrement;
  bool _nameVisible = false;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _currentScore = widget.playerState.score ?? 0;
    _currentRoundScore = widget.playerState.roundScore ?? 0;
    widget.controller?.bind(
      setRoundScore: _handleSetRoundScore,
      setScore: _handleSetScore,
      triggerConfetti: _handleTriggerConfetti,
      clearConfetti: _handleClearConfetti,
    );
  }

  @override
  void didUpdateWidget(PlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.dispose();
      widget.controller?.bind(
        setRoundScore: _handleSetRoundScore,
        setScore: _handleSetScore,
        triggerConfetti: _handleTriggerConfetti,
        clearConfetti: _handleClearConfetti,
      );
    }
    // If animation flag changes, reconcile overlay immediately
    if (oldWidget.animateScoreOverlay != widget.animateScoreOverlay) {
      final int newScoreVal = widget.playerState.score ?? _currentScore;
      final int delta = newScoreVal - _currentScore;
      if (widget.animateScoreOverlay) {
        if (delta != 0) {
          _scoreOverlayController.increment?.call(delta);
        }
      } else {
        _scoreOverlayController.setScore?.call(newScoreVal);
      }
    }
    final newScore = widget.playerState.score ?? 0;
    final int? newRoundScore = widget.playerState.roundScore;
    if (newScore != _currentScore) {
      final incrementAmount = newScore - _currentScore;
      if (incrementAmount != 0) {
        _scoreOverlayController.increment?.call(incrementAmount);
        setState(() {
          _lastIncrement =
              incrementAmount; // show +N on forward, -N on rollback
        });
      }
      _currentScore = newScore;
    }
    if (newRoundScore != null) {
      if (newRoundScore != _currentRoundScore) {
        final roundDelta = newRoundScore - _currentRoundScore;
        if (roundDelta != 0) {
          _statusScoreController.increment?.call(roundDelta);
        }
        setState(() {
          _currentRoundScore = newRoundScore;
          _lastIncrement = newRoundScore;
        });
      }
    }
    // NOTE: We intentionally do NOT clear _lastIncrement when newRoundScore is null.
    // The controller's setRoundScore() is the authoritative source for transient score state.
    // If the controller wants to clear the transient chip, it calls setRoundScore(0).
    // This prevents race conditions where widget rebuilds with stale PlayerState.roundScore
    // clear the transient chip before the next rebuild with correct roundScore arrives.
    if (!widget.showNameChip ||
        widget.playerState.displayName == null ||
        widget.playerState.displayName!.isEmpty) {
      _nameVisible = false;
    }
  }

  void _handleSetRoundScore(int newRoundScore) {
    if (!mounted) return;
    if (newRoundScore == _currentRoundScore) {
      if (newRoundScore == 0 && _lastIncrement != null) {
        setState(() {
          _lastIncrement = null;
        });
      }
      return;
    }
    if (newRoundScore == 0) {
      _statusScoreController.setScore?.call(0);
      setState(() {
        _currentRoundScore = 0;
        _lastIncrement = null;
      });
      return;
    }
    final int roundDelta = newRoundScore - _currentRoundScore;
    if (roundDelta != 0) {
      _statusScoreController.increment?.call(roundDelta);
    }
    setState(() {
      _currentRoundScore = newRoundScore;
      _lastIncrement = newRoundScore;
    });
  }

  void _handleSetScore(int newScore) {
    if (!mounted) return;
    // Use setScore directly to avoid race conditions with rapid scrolling
    // The PlayerScore widget tracks its own _currentValue internally and will
    // animate from the displayed value to the target value correctly
    // Note: Don't clear _lastIncrement here - that's only for round scores (transient chip)
    if (newScore != _currentScore) {
      _scoreOverlayController.setScore?.call(newScore);
      setState(() {
        _currentScore = newScore;
      });
    }
  }

  void _handleTriggerConfetti() {
    if (!mounted) return;
    setState(() {
      _showConfetti = true;
    });
  }

  void _handleClearConfetti() {
    if (!mounted) return;
    setState(() {
      _showConfetti = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Use text-muted from app theme for name chip
    final Color nameColor = appTheme.textMuted;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        onTap: () {
          if (!widget.showNameChip ||
              (widget.playerState.displayName == null ||
                  widget.playerState.displayName!.isEmpty)) {
            return;
          }
          setState(() {
            _nameVisible = !_nameVisible;
          });
        },
        child: SizedBox(
          width: 90,
          height: 192,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double avatarSize = 63.0;
              // Overflow distance for name chip (top)
              const double overflowDistance = 20;
              final double totalH = constraints.maxHeight;
              final double avatarTop = (totalH - avatarSize) / 2;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        _buildAvatar(),
                        // Running score at top of avatar
                        if (widget.showScoreOverlay &&
                            widget.playerState.score != null)
                          Positioned(
                            top: avatarTop - 24.0,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PlayerScore(
                                  key: const ValueKey('running_score_overlay'),
                                  initialScore: _currentScore,
                                  controller: _scoreOverlayController,
                                ),
                              ],
                            ),
                          ),
                        // Rank icon on left side of avatar
                        Positioned(
                          bottom: totalH - (avatarTop + avatarSize) + 16.0,
                          left: 2,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeInOut,
                            opacity: (widget.showRankIcons &&
                                    widget.rankOverride != null)
                                ? 1.0
                                : 0.0,
                            child: IgnorePointer(
                              ignoring: !(widget.showRankIcons &&
                                  widget.rankOverride != null),
                              child: widget.rankOverride != null
                                  ? RankWidget(
                                      key: ValueKey<String>(
                                          'rank_${widget.playerState.playerId}_${widget.rankOverride}'),
                                      rank: widget.rankOverride!,
                                      animationStyle: widget.rankAnimationStyle,
                                      show: widget.showRankIcons,
                                    )
                                  : const SizedBox(width: 34, height: 34),
                            ),
                          ),
                        ),
                        // Status indicator (AnswerScoreCard) at bottom
                        Positioned(
                          top: avatarTop + avatarSize + 24.0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatusIndicator(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.showNameChip &&
                      (widget.playerState.displayName?.isNotEmpty ?? false))
                    Positioned(
                      top: _isStatusIndicatorVisible()
                          ? -overflowDistance
                          : avatarTop -
                              36.0, // 24px above avatar (avatarTop - 24.0 was at edge, need another 24px)
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeInOut,
                        opacity: _nameVisible ? 1.0 : 0.0,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeInOut,
                          offset: _nameVisible
                              ? const Offset(0, 0.0)
                              : const Offset(0, 0.4),
                          child: Center(
                            child: SizedBox(
                              width: 92.0,
                              child: _nameVisible
                                  ? TextScroll(
                                      key: ValueKey(
                                          widget.playerState.displayName),
                                      widget.playerState.displayName!,
                                      delayBefore: const Duration(seconds: 1),
                                      pauseBetween: const Duration(seconds: 1),
                                      pauseOnBounce: const Duration(seconds: 1),
                                      mode: TextScrollMode.bouncing,
                                      style: AppFont.primaryTextStyle(
                                        context,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14.0,
                                        color: nameColor,
                                      ),
                                      textAlign: TextAlign.center,
                                      selectable: false,
                                    )
                                  : Text(
                                      key: ValueKey(
                                          widget.playerState.displayName),
                                      widget.playerState.displayName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                      style: AppFont.primaryTextStyle(
                                        context,
                                        fontWeight: FontWeight.w300,
                                        fontSize: 14.0,
                                        color: nameColor,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Confetti overlay for highest scorer
                  if (_showConfetti)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: PlayerConfettiOverlay(
                          onComplete: _handleClearConfetti,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // String _formatWithCommas(int number) {
  //   return number.toString().replaceAllMapped(
  //         RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
  //         (Match m) => '${m[1]},',
  //       );
  // }

  Widget _buildAvatar() {
    const avatarSize = 70.0;

    // Get app theme for colors
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Use app theme's bg color for SVG background
    final Color svgBackgroundColor = appTheme.bgLight;

    // Build the avatar content based on whether it's SVG or raster image
    Widget avatarContent;
    final String? avatarUrl = widget.playerState.avatarUrl;

    if (avatarUrl != null && avatarUrl.toLowerCase().endsWith('.svg')) {
      // Handle SVG images with flutter_svg
      // Use Container with circular shape and background color (theme fg)
      // BoxFit.contain ensures the entire square SVG is visible inside the circle
      avatarContent = Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: svgBackgroundColor,
        ),
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.network(
              avatarUrl,
              fit: BoxFit.contain,
              placeholderBuilder: (context) => Container(
                color: appTheme.bgLight,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        ),
      );
    } else if (avatarUrl != null) {
      // Handle raster images (PNG, JPEG, etc.) from network
      avatarContent = Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: NetworkImage(avatarUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // Handle null avatarUrl - use default user SVG icon
      avatarContent = Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: svgBackgroundColor,
        ),
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SvgPicture.asset(
              'assets/icons/user.svg',
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(
                // ignore: deprecated_member_use
                appTheme.bgLight,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      );
    }

    // If no tracker is provided, we are in a context without a countdown, so we
    // show a static ring for all players. The color will be determined by role.
    if (widget.deadlineProgressTracker == null) {
      return PlayerRingProgress(
        // Let countdown state logic handle role-based coloring
        ringState: widget.playerState.ringState,
        ringProgress: 0.0, // Inverts to a full ring
        isSelf: widget.isSelf,
        isHost: widget.playerState.isHost,
        child: avatarContent,
      );
    }

    // Wrap avatar with progress ring that rebuilds via ListenableBuilder
    return ListenableBuilder(
      listenable: widget.deadlineProgressTracker!,
      builder: (context, child) {
        final ringProgress = widget.deadlineProgressTracker!.progress;
        return PlayerRingProgress(
          ringState: widget.playerState.ringState,
          ringProgress: ringProgress,
          isSelf: widget.isSelf,
          isHost: widget.playerState.isHost,
          child: child!,
        );
      },
      child: avatarContent,
    );
  }

  bool _isStatusIndicatorVisible() {
    switch (widget.playerState.status) {
      case PlayerStatus.waiting:
      case PlayerStatus.ready:
      case PlayerStatus.none:
        return false;
      case PlayerStatus.number:
        return true;
      case PlayerStatus.answer:
        return widget.playerState.submittedAnswer != null;
    }
  }

  Widget _buildStatusIndicator() {
    switch (widget.playerState.status) {
      case PlayerStatus.waiting:
      case PlayerStatus.ready:
        // No longer show indicators for waiting/ready states
        // Ring handles this feedback now
        return const SizedBox.shrink();
      case PlayerStatus.number:
      case PlayerStatus.answer:
        // Both number and answer status now show AnswerScoreCard
        final ans = widget.playerState.submittedAnswer;
        if (ans == null) return const SizedBox.shrink();
        // Prefer per-question round score from state when available (e.g., review)
        int visibleRound = widget.playerState.roundScore ?? _currentRoundScore;
        if (visibleRound < 0) visibleRound = 0; // clamp
        final Color bg = scoreToColor(visibleRound);
        return AnswerScoreCard(
          answer: ans,
          score: visibleRound,
          backgroundColor: bg.withAlpha((0.3 * 255).toInt()),
        );
      case PlayerStatus.none:
        return const SizedBox.shrink();
    }
  }
}
