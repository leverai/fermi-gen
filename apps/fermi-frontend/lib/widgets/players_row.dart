import 'package:flutter/material.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/rank_widget.dart';
import 'package:fermi_frontend/widgets/player_widget_controller.dart';
import 'package:fermi_frontend/widgets/question_deadline_progress_tracker.dart';

/// Displays a horizontal row of players with no spacing between widgets.
class PlayersRow extends StatefulWidget {
  const PlayersRow({
    super.key,
    required this.players,
    this.alignment = MainAxisAlignment.center,
    this.maxVisible,
    this.showScoreOverlay = true,
    this.animateScoreOverlay = true,
    this.controllerById,
    this.showNameChip = false,
    this.showRankIcons = false,
    this.rankAnimationStyle = RankAnimationStyle.none,
    this.reorderDuration = const Duration(milliseconds: 500),
    this.reorderCurve = Curves.easeInOut,
    this.currentPlayerId,
    this.questionIndex,
    this.deadlineProgressTracker,
    this.finalRanks,
  });

  /// Player widgets to render, already sorted by display order.
  final List<PlayerState> players;
  final MainAxisAlignment alignment;
  final int? maxVisible;
  final bool showScoreOverlay;
  final bool animateScoreOverlay;
  final Map<String, PlayerWidgetController>?
      controllerById; // optional keyed by playerId
  final bool showNameChip; // when true, PlayerWidget shows name above avatar
  /// When true, medals are shown for top 3 players (gold/silver/bronze).
  /// In review mode, uses finalRanks to show static final game ranks.
  /// In live mode, calculates from sorted position.
  final bool showRankIcons; // when true, PlayerWidget shows rank medals
  final RankAnimationStyle rankAnimationStyle; // animation style for medals
  final Duration reorderDuration;
  final Curve reorderCurve;

  /// The current player's ID. When provided, a self-ring will show around
  /// the matching player's avatar (unless they are host, in which case host ring shows).
  final String? currentPlayerId;

  /// Optional question index to trigger re-centering when changing questions
  final int? questionIndex;

  /// Notifier for deadline progress
  final QuestionDeadlineProgressTracker? deadlineProgressTracker;

  /// Final ranks for top 3 players (used in review mode to keep rank icons static)
  final Map<String, Rank>? finalRanks;

  @override
  State<PlayersRow> createState() => _PlayersRowState();
}

class _PlayersRowState extends State<PlayersRow> {
  ScrollController? _scrollController;
  bool _needsInitialScroll = true;

  @override
  void initState() {
    super.initState();
    // Initialize scroll controller only if we have >3 players
    if (widget.players.length > 3) {
      _scrollController = ScrollController();
    }
  }

  @override
  void didUpdateWidget(PlayersRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if we need to initialize/dispose scroll controller based on player count
    final bool wasScrollable = oldWidget.players.length > 3;
    final bool isScrollable = widget.players.length > 3;

    if (!wasScrollable && isScrollable) {
      _scrollController = ScrollController();
      _needsInitialScroll = true;
    } else if (wasScrollable && !isScrollable) {
      _scrollController?.dispose();
      _scrollController = null;
      _needsInitialScroll = true;
    }

    // Trigger re-center when question changes (explicit trigger)
    if (widget.questionIndex != null &&
        widget.questionIndex != oldWidget.questionIndex) {
      _needsInitialScroll = true;
    }
    // Also re-center if currentPlayerId changes (e.g., game restart)
    else if (widget.currentPlayerId != oldWidget.currentPlayerId) {
      _needsInitialScroll = true;
    }
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  void _scrollToCurrentPlayer() {
    if (_scrollController == null ||
        !_scrollController!.hasClients ||
        widget.currentPlayerId == null) {
      return;
    }

    // In review mode, use sorted players list; otherwise use original
    final List<PlayerState> playersToSearch = _getSortedPlayers();

    // Find the index of the current player
    final int currentPlayerIndex = playersToSearch.indexWhere(
      (player) => player.playerId == widget.currentPlayerId,
    );

    if (currentPlayerIndex == -1) return;

    const double itemWidth = 108.0;
    const double spacing = 0.0;

    // Calculate the position to center the current player
    final double playerCenter =
        (currentPlayerIndex * (itemWidth + spacing)) + (itemWidth / 2);
    final double viewportWidth = _scrollController!.position.viewportDimension;
    final double targetScroll = (playerCenter - (viewportWidth / 2)).clamp(
      _scrollController!.position.minScrollExtent,
      _scrollController!.position.maxScrollExtent,
    );

    // Animate to the target position
    _scrollController!.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  /// Sort players by cumulative score (descending) for review mode
  List<PlayerState> _getSortedPlayers() {
    if (!widget.showRankIcons) {
      return widget.players;
    }
    final List<PlayerState> sorted = List<PlayerState>.from(widget.players);
    sorted.sort((a, b) {
      // Sort by cumulative score (descending)
      final int scoreA = a.score ?? 0;
      final int scoreB = b.score ?? 0;
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // Descending order
      }
      // Tiebreaker: use playerId for stable sort
      final String idA = a.playerId ?? '';
      final String idB = b.playerId ?? '';
      return idA.compareTo(idB);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    // In review mode, sort players by cumulative score (descending) to reflect rank at current question
    // This ensures players are ordered correctly when scrolling through question history
    final List<PlayerState> sortedPlayers = _getSortedPlayers();

    // Schedule scroll after layout if needed
    if (_needsInitialScroll && _scrollController != null) {
      _needsInitialScroll = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // If ScrollController doesn't have clients yet, wait a bit longer
        if (_scrollController != null && !_scrollController!.hasClients) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _scrollToCurrentPlayer();
            }
          });
        } else {
          _scrollToCurrentPlayer();
        }
      });
    }

    // If 3 or fewer: center-aligned, slot-based layout with animated reordering.
    if (sortedPlayers.length <= 3) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const double itemWidth = 108.0;
          const double itemHeight = 132.0;
          // Extra height to accommodate transient score chip overflow (~32px below)
          const double overflowMargin = 32.0;
          final int itemCount = sortedPlayers.length;
          final double totalWidth = itemCount * itemWidth;
          final double availableWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : totalWidth;
          final double leftInset =
              ((availableWidth - totalWidth) / 2.0).clamp(0.0, double.infinity);

          final List<Widget> positioned = <Widget>[];
          for (int i = 0; i < sortedPlayers.length; i++) {
            final PlayerState playerState = sortedPlayers[i];
            final String keyId = playerState.playerId ?? 'idx_$i';
            final double left = leftInset + (i * itemWidth);
            final PlayerWidgetController? controller =
                (playerState.playerId != null && widget.controllerById != null)
                    ? widget.controllerById![playerState.playerId!]
                    : null;

            final bool isSelf = widget.currentPlayerId != null &&
                playerState.playerId != null &&
                playerState.playerId == widget.currentPlayerId;

            // Determine rank: use finalRanks if available (review mode), otherwise calculate from position
            Rank? rankOverride;
            if (widget.showRankIcons) {
              if (widget.finalRanks != null && playerState.playerId != null) {
                // In review mode, use stored final ranks (static, doesn't change during reordering)
                rankOverride = widget.finalRanks![playerState.playerId];
              } else {
                // In live mode, calculate from sorted position
                rankOverride = (i == 0
                    ? Rank.first
                    : (i == 1 ? Rank.second : (i == 2 ? Rank.third : null)));
              }
            }

            positioned.add(AnimatedPositioned(
              key: ValueKey<String>('slot_$keyId'),
              duration: widget.reorderDuration,
              curve: widget.reorderCurve,
              left: left,
              top: 0.0,
              width: itemWidth,
              height: itemHeight,
              child: PlayerWidget(
                key: ValueKey<String>('player_widget_$keyId'),
                playerState: playerState,
                showScoreOverlay: widget.showScoreOverlay,
                animateScoreOverlay: widget.animateScoreOverlay,
                controller: controller,
                showNameChip: widget.showNameChip,
                showRankIcons: widget.showRankIcons,
                rankAnimationStyle: widget.rankAnimationStyle,
                rankOverride: rankOverride,
                isSelf: isSelf,
                deadlineProgressTracker: widget.deadlineProgressTracker,
              ),
            ));
          }

          return SizedBox(
            height: itemHeight + overflowMargin,
            child: Stack(
              clipBehavior: Clip.none,
              children: positioned,
            ),
          );
        },
      );
    }

    // For >3 players: horizontally scrollable strip with AnimatedPositioned reordering.
    return LayoutBuilder(
      builder: (context, constraints) {
        const double itemWidth = 108.0;
        const double itemHeight = 132.0;
        final int itemCount = sortedPlayers.length;
        final double contentWidth = itemCount * itemWidth;

        final List<Widget> positioned = <Widget>[];
        for (int i = 0; i < sortedPlayers.length; i++) {
          final PlayerState playerState = sortedPlayers[i];
          final String keyId = playerState.playerId ?? 'idx_$i';
          final double left = i * itemWidth;
          final PlayerWidgetController? controller =
              (playerState.playerId != null && widget.controllerById != null)
                  ? widget.controllerById![playerState.playerId!]
                  : null;

          final bool isSelf = widget.currentPlayerId != null &&
              playerState.playerId != null &&
              playerState.playerId == widget.currentPlayerId;

          // Determine rank: use finalRanks if available (review mode), otherwise calculate from position
          Rank? rankOverride;
          if (widget.showRankIcons) {
            if (widget.finalRanks != null && playerState.playerId != null) {
              // In review mode, use stored final ranks (static, doesn't change during reordering)
              rankOverride = widget.finalRanks![playerState.playerId];
            } else {
              // In live mode, calculate from sorted position
              rankOverride = (i == 0
                  ? Rank.first
                  : (i == 1 ? Rank.second : (i == 2 ? Rank.third : null)));
            }
          }

          positioned.add(AnimatedPositioned(
            key: ValueKey<String>('strip_$keyId'),
            duration: widget.reorderDuration,
            curve: widget.reorderCurve,
            left: left,
            top: 0.0,
            width: itemWidth,
            height: itemHeight,
            child: PlayerWidget(
              key: ValueKey<String>('player_widget_$keyId'),
              playerState: playerState,
              showScoreOverlay: widget.showScoreOverlay,
              animateScoreOverlay: widget.animateScoreOverlay,
              controller: controller,
              showNameChip: widget.showNameChip,
              showRankIcons: widget.showRankIcons,
              rankAnimationStyle: widget.rankAnimationStyle,
              rankOverride: rankOverride,
              isSelf: isSelf,
              deadlineProgressTracker: widget.deadlineProgressTracker,
            ),
          ));
        }

        // Use extra height to accommodate transient score chip overflow (~32px below)
        const double overflowMargin = 32.0;
        return SizedBox(
          height: itemHeight + overflowMargin,
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(overscroll: false),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              child: SizedBox(
                width: contentWidth,
                height: itemHeight + overflowMargin,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: positioned,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
