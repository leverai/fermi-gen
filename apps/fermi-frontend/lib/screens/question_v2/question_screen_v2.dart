import 'package:flutter/material.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2_controller.dart';
import 'package:fermi_frontend/screens/question_v2/widgets/game_carousel.dart';
import 'package:fermi_frontend/screens/question_v2/widgets/game_card.dart';
import 'package:fermi_frontend/screens/question_v2/models/question_pane_state.dart';
import 'package:fermi_frontend/widgets/players_row.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/services/game_session.dart';
import 'package:fermi_frontend/screens/question_v2/helpers/leave.dart'
    as leave_helper;
import 'package:fermi_frontend/screens/question_v2/helpers/snack.dart' as snack;

import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/logger.dart';
import 'package:fermi_frontend/widgets/rank_confetti_overlay.dart';

class QuestionScreenV2 extends StatefulWidget {
  const QuestionScreenV2({
    super.key,
    required this.gameId,
    required this.realtime,
    required this.questionCount,
    required this.isHost,
    this.session,
    this.initialPlayers = const [],
    this.showLeaveButton = true,
    // Tutorial keys for onboarding
    this.questionWidgetKey,
    this.likeWidgetKey,
    this.unitKey,
    this.answerScaleKey,
    this.onControllerCreated,
    this.onFinish,
    this.onBeforeShowDialog,
  });

  final String gameId;
  final GameRealtime realtime;
  final int questionCount;
  final bool isHost;
  final GameSessionController? session;
  final List<PlayerState> initialPlayers;
  final bool showLeaveButton;
  // Tutorial keys for onboarding
  final Key? questionWidgetKey;
  final Key? likeWidgetKey;
  final Key? unitKey;
  final Key? answerScaleKey;
  // Callback to expose controller (for onboarding)
  final ValueChanged<QuestionScreenV2Controller>? onControllerCreated;
  // Optional callback for finish button (for onboarding)
  final VoidCallback? onFinish;
  // Optional callback called before showing dialogs (e.g., to dismiss tutorial overlay)
  final VoidCallback? onBeforeShowDialog;

  @override
  State<QuestionScreenV2> createState() => _QuestionScreenV2State();
}

class _QuestionScreenV2State extends State<QuestionScreenV2> {
  late final QuestionScreenV2Controller _controller;

  @override
  void initState() {
    super.initState();
    _controller = QuestionScreenV2Controller(
      realtime: widget.realtime,
      gameId: widget.gameId,
      questionCount: widget.questionCount,
    );
    _controller.addListener(_onControllerChanged);
    _controller.attach();

    // Expose controller to parent (for onboarding)
    widget.onControllerCreated?.call(_controller);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLeave() async {
    if (_controller.isReviewMode) {
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/main', (route) => false);
      }
      return;
    }

    // Dismiss tutorial overlay if present (e.g., during onboarding)
    // This allows the dialog to be interacted with
    widget.onBeforeShowDialog?.call();

    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    await leave_helper.confirmLeaveDialog(
      context: context,
      highlightColor: appTheme.danger,
      onConfirm: () async {
        try {
          if (widget.session != null) {
            await widget.session!.leaveGame();
          }
        } catch (e) {
          if (mounted) {
            snack.showSnack(context, 'Failed to leave: $e');
          }
          return;
        }
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/main', (route) => false);
        }
      },
    );
  }

  Future<void> _handleSubmit() async {
    await _controller.submitAnswer();
  }

  Future<void> _handleNext() async {
    // Check if we're on the last question and in finished state
    // If onFinish callback is provided, use it (for onboarding)
    final bool isLastQuestion =
        _controller.currentIndex == widget.questionCount - 1;
    final bool isFinished = _getPaneState() == QuestionPaneState.finished;

    if (widget.onFinish != null && isLastQuestion && isFinished) {
      widget.onFinish!();
      return;
    }

    if (_controller.isReviewMode) {
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/main', (route) => false);
      }
      return;
    }
    await _controller.requestNext();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    // Height is now fixed based on GameCard's intrinsic content height.
    // See game_card.dart for the breakdown of this value.
    const double carouselHeight = kGameCardTotalHeight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleLeave();
      },
      child: Builder(builder: (context) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: appTheme.bgDark,
            ),
            Padding(
              padding: const EdgeInsets.only(
                  top: 0, bottom: 72, left: 12, right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Players row
                  SafeArea(
                    bottom: false,
                    child: PlayersRow(
                      players: _controller
                          .getPlayersForIndex(_controller.currentIndex),
                      controllerById: _controller.playerControllers,
                      showScoreOverlay: true,
                      animateScoreOverlay: true,
                      showNameChip: true,
                      showRankIcons: _controller.isReviewMode,
                      currentPlayerId: widget.realtime.currentPlayerId,
                      questionIndex: _controller.currentIndex,
                      deadlineProgressTracker:
                          _controller.deadlineProgressTracker,
                      finalRanks: _controller.finalRanks,
                    ),
                  ),
                  // Spacer to center carousel vertically in remaining space
                  const Spacer(),
                  // Game carousel (fixed height, not expanded)
                  GameCarousel(
                    itemCount: widget.questionCount,
                    currentIndex: _controller.currentIndex,
                    pageController: _controller.pageController,
                    itemBuilder: (context, index, realIndex) {
                      return _buildGameCard(realIndex);
                    },
                    onPageChanged: (index) {
                      _controller.onCarouselPageChanged(index);
                    },
                    height: carouselHeight,
                    enableUserSwipe: _controller.isReviewMode,
                  ),
                  // Bottom spacer to balance layout
                  const Spacer(),
                ],
              ),
            ),
            if (widget.showLeaveButton)
              LeaveButtonOverlay(
                iconColor: appTheme.border,
                splashColor: appTheme.borderMuted,
                onPressed: _handleLeave,
              ),
            // Rank confetti overlay for top 3 players at game end
            if (_controller.confettiRank != null && _controller.isReviewMode)
              Positioned.fill(
                child: IgnorePointer(
                  child: RankConfettiOverlay(
                    rank: _controller.confettiRank!,
                    // Don't clear confetti in review mode - it should persist
                    onComplete: null,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildGameCard(int index) {
    final state = _controller.getQuestionState(index);
    if (state == null) {
      return const SizedBox.shrink();
    }

    final bool isCurrentQuestion = index == _controller.currentIndex;
    final bool showFeedback = state.isRevealed;

    // Get display answer from controller (single source of truth)
    final AnswerValue displayAnswer = _controller.getDisplayAnswer(index);

    // Always pass revealed props when question is revealed - let widget decide how to use them
    final revealedAnswer =
        showFeedback ? _controller.getRevealedAnswer(index) : null;
    final revealedColor =
        showFeedback ? _controller.getRevealedColor(index) : null;

    AppLogger.debug(
        '_buildGameCard[$index]: isCurrentQuestion=$isCurrentQuestion, showFeedback=$showFeedback, displayAnswer=$displayAnswer, revealedAnswer=$revealedAnswer, revealedColor=$revealedColor');

    // Get player's percentile for this question
    final percentile = _controller.getMyPercentileForIndex(index);
    final percentileValue =
        percentile != null ? (percentile * 100).round() : null;
    final showPercentile = showFeedback && percentile != null && percentile > 0;

    // Get submitted answer for THIS question (per-question, not shared)
    final AnswerValue? submittedAnswerForThisQuestion;
    final myId = widget.realtime.currentPlayerId;

    if (state.isRevealed) {
      // For revealed questions, use stored submitted answer
      submittedAnswerForThisQuestion = state.submittedAnswers[myId];
    } else if (isCurrentQuestion) {
      // For current question in live mode, use localSubmittedAnswer
      submittedAnswerForThisQuestion = _controller.localSubmittedAnswer;
    } else {
      // For non-current non-revealed questions, no submitted answer
      submittedAnswerForThisQuestion = null;
    }

    // Get button-related props
    final paneState = _getPaneStateForIndex(index);
    final bool isLast = index == widget.questionCount - 1;
    final deadlineProgress = isCurrentQuestion
        ? (_controller.deadlineProgressTracker?.progress ?? 0.0)
        : 0.0;
    final autoNextProgress =
        isCurrentQuestion ? _controller.autoNextProgress : 0.0;

    // Get converted answers for the current player (if revealed)
    final Map<String, AnswerValue>? otherPlayersAnswers;
    final Map<String, String?>? otherPlayersAvatars;
    String? currentPlayerAvatarUrl;

    if (showFeedback && state.convertedAnswers.isNotEmpty) {
      otherPlayersAnswers = state.convertedAnswers[myId];

      // Extract avatar URLs for other players (excluding current player)
      otherPlayersAvatars = {};
      for (final player in state.players) {
        if (player.playerId != null) {
          if (player.playerId == myId) {
            // Store current player's avatar
            currentPlayerAvatarUrl = player.avatarUrl;
          } else {
            // Store other players' avatars
            otherPlayersAvatars[player.playerId!] = player.avatarUrl;
          }
        }
      }
    } else {
      otherPlayersAnswers = null;
      otherPlayersAvatars = null;
      currentPlayerAvatarUrl = null;
    }

    return GameCard(
      questionText: state.questionText,
      tags: state.tags,
      currentAnswer: displayAnswer,
      submittedAnswer: submittedAnswerForThisQuestion,
      unitOptions: state.unitOptions,
      units: state.units,
      currentLocale: _controller.currentLocale,
      onAnswerChanged: isCurrentQuestion ? _controller.onAnswerChanged : (_) {},
      onLocaleChanged: isCurrentQuestion ? _controller.onLocaleChanged : (_) {},
      revealedAnswer: revealedAnswer,
      revealedColor: revealedColor,
      editable: isCurrentQuestion && !_controller.isReviewMode && !showFeedback,
      showFeedback: showFeedback,
      initialLikes: state.upvotes,
      initialVoteState: state.voteState,
      onUpvote: isCurrentQuestion ? _controller.onUpvote : null,
      onDeUpvote: isCurrentQuestion ? _controller.onDeUpvote : null,
      onDownvote: isCurrentQuestion ? _controller.onDownvote : null,
      onDeDownvote: isCurrentQuestion ? _controller.onDeDownvote : null,
      unitOptionsNotifier:
          isCurrentQuestion ? _controller.unitOptionsNotifier : null,
      unitTapeController:
          isCurrentQuestion ? _controller.unitTapeController : null,
      reviewMode: _controller.isReviewMode,
      // Pass tutorial keys only for current question
      questionWidgetKey: isCurrentQuestion ? widget.questionWidgetKey : null,
      likeWidgetKey: isCurrentQuestion ? widget.likeWidgetKey : null,
      unitKey: isCurrentQuestion ? widget.unitKey : null,
      answerScaleKey: isCurrentQuestion ? widget.answerScaleKey : null,
      // Button-related props
      paneState: paneState,
      isLast: isLast,
      isHost: _controller.isHost,
      isCurrentQuestion: isCurrentQuestion,
      onSubmit: isCurrentQuestion ? _handleSubmit : null,
      onNext: isCurrentQuestion ? _handleNext : null,
      autoNextProgress: autoNextProgress,
      questionDeadlineProgress: deadlineProgress,
      submitButtonKey:
          null, // Don't use answerWidgetKey for submit button to avoid key conflicts
      // Percentile props
      percentile: percentileValue ?? 0,
      showPercentile: showPercentile,
      // Other players' converted answers
      otherPlayersAnswers: otherPlayersAnswers,
      otherPlayersAvatars: otherPlayersAvatars,
      currentPlayerAvatarUrl: currentPlayerAvatarUrl,
    );
  }

  QuestionPaneState _getPaneState() {
    return _getPaneStateForIndex(_controller.currentIndex);
  }

  QuestionPaneState _getPaneStateForIndex(int index) {
    if (_controller.isReviewMode) {
      return QuestionPaneState.finished;
    }
    final state = _controller.getQuestionState(index);
    if (state == null) {
      return QuestionPaneState.started;
    }
    if (state.isRevealed) {
      return QuestionPaneState.finished;
    }
    // Check if this question has a submitted answer
    final myId = widget.realtime.currentPlayerId;
    final bool hasSubmittedAnswer = state.submittedAnswers.containsKey(myId);
    // For current question, also check localSubmittedAnswer
    if (index == _controller.currentIndex &&
        _controller.localSubmittedAnswer != null) {
      return QuestionPaneState.locked;
    }
    if (hasSubmittedAnswer) {
      return QuestionPaneState.locked;
    }
    return QuestionPaneState.started;
  }
}
