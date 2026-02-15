import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/screens/survival/survival_screen_controller.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/preload_service.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/screens/question_v2/widgets/game_card.dart';
import 'package:fermi_frontend/screens/question_v2/models/question_pane_state.dart';
import 'package:fermi_frontend/widgets/animated_like_dislike.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';
import 'package:fermi_frontend/widgets/pa_card.dart';
import 'package:fermi_frontend/widgets/styled_dialog.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:fermi_frontend/utils/number_decompose.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/answer_format.dart';
import 'package:fermi_frontend/services/rate_app_service.dart';

/// Survival mode screen - single player timed questions until failure.
class SurvivalScreen extends StatefulWidget {
  final int initialCurrentStreak;
  final int initialBestStreak;
  final bool withAd;

  const SurvivalScreen({
    super.key,
    this.initialCurrentStreak = 0,
    this.initialBestStreak = 0,
    this.withAd = false,
  });

  @override
  State<SurvivalScreen> createState() => _SurvivalScreenState();
}

class _SurvivalScreenState extends State<SurvivalScreen> {
  late SurvivalScreenController _controller;
  bool _isPAPopupPending = false;
  bool _isShowingLeaveDialog = false;

  @override
  void initState() {
    super.initState();
    final apiService = context.read<ApiService>();
    final authService = context.read<AuthService>();
    final preloadService = context.read<PreloadService>();

    _controller = SurvivalScreenController(
      apiService: apiService,
      userLocale: authService.locale ?? 'US',
      initialCurrentStreak: widget.initialCurrentStreak,
      initialBestStreak: widget.initialBestStreak,
      gameConfig: preloadService.cachedConfig,
      initialWithAd: widget.withAd,
    );
    _controller.onShowPACard = _showPACardPopup;
    _controller.addListener(_onControllerChanged);
    _controller.attach();
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
    // If already submitted, just navigate back
    if (_controller.isSubmitted) {
      _navigateToMain();
      return;
    }

    if (_isShowingLeaveDialog) return;
    _isShowingLeaveDialog = true;

    // Show confirmation dialog
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StyledDialog(
            message: 'Your answer will be submitted.',
            primaryButtonLabel: 'Leave',
            primaryButtonColor: appTheme.danger,
            onPrimaryPressed: () => Navigator.of(ctx).pop(true),
            secondaryButtonLabel: 'Cancel',
            onSecondaryPressed: () => Navigator.of(ctx).pop(false),
            showAsDialog: true,
          );
        },
      );

      if (confirmed == true) {
        await _controller.submitBeforeLeave();
        _navigateToMain();
      }
    } finally {
      _isShowingLeaveDialog = false;
    }
  }

  void _navigateToMain() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/main');
    }
  }

  Future<void> _handleSubmit() async {
    await _controller.submitAnswer();
  }

  Future<void> _handleNext() async {
    // Block if PA popup is pending
    if (_isPAPopupPending) return;

    if (_controller.passed) {
      await _controller.requestNext();
    } else if (_controller.canUseAdSave) {
      // Player failed but can save with ad
      await _handleContinueWithAd();
    } else {
      // Failed and no ad save available
      _navigateToMain();
    }
  }

  /// Show PA card popup if the player's percentile qualifies.
  /// Returns a Future that completes when the popup is closed.
  Future<void> _showPACardPopup() async {
    final answerResponse = _controller.answerResponse;
    if (answerResponse == null) return;

    final percentile = answerResponse.percentile;
    // Check if tier exists (percentile qualifies for a card)
    if (PACard.getTierForPercentile(percentile) == null) return;

    final question = _controller.currentQuestion;
    if (question == null) return;

    // Format the user's answer with proper unit abbreviation
    final userAnswerValue = answerResponse.userAnswer;
    final formattedUserAnswer = _formatAnswerWithUnit(
      userAnswerValue,
      _controller.getUnitAbbreviationFromId(userAnswerValue.unit),
    );

    // Format the correct answer with proper unit abbreviation
    final correctAnswerValue = answerResponse.convertedCorrectAnswer;
    final formattedCorrectAnswer = _formatAnswerWithUnit(
      correctAnswerValue,
      _controller.getUnitAbbreviationFromId(correctAnswerValue.unit),
    );

    // Wait 1 second before showing the popup
    setState(() => _isPAPopupPending = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _isPAPopupPending = false);

    if (!mounted) return;

    // Determine the main button label based on game state
    final String mainLabel;
    if (_controller.passed) {
      mainLabel = 'Next';
    } else if (_controller.canUseAdSave) {
      mainLabel = 'Save Streak 🎬';
    } else {
      mainLabel = 'Finish';
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: PACard(
              percentile: percentile,
              questionText: question.text,
              userAnswer: formattedUserAnswer,
              correctAnswer: formattedCorrectAnswer,
              animate: true,
              onClose: () => Navigator.of(ctx).pop(),
              mainButtonLabel: mainLabel,
              onMainButtonPressed: () {
                Navigator.of(ctx).pop();
                _handleNext();
              },
            ),
          ),
        );
      },
    );

    // Prompt for app review if this was a top-tier PA card
    final tier = PACard.getTierForPercentile(percentile);
    if (tier == PAChiermontTier.top1 ||
        tier == PAChiermontTier.top5 ||
        tier == PAChiermontTier.top10) {
      await RateAppService.instance.maybePromptReview();
    }
  }

  /// Format an AnswerValue with a specific unit abbreviation override.
  String _formatAnswerWithUnit(AnswerValue value, String unitAbbreviation) {
    final baseFormatted = formatAnswerValue(
      value.copyWith(unit: unitAbbreviation),
    );
    return baseFormatted;
  }

  Future<void> _handleContinueWithAd() async {
    await _controller.continueWithAd(
      onFailed: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad not available. Try again later.')),
        );
        _navigateToMain();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    if (_controller.isLoading) {
      return ResponsiveContainer(
        backgroundColor: appTheme.bgDark,
        child: Scaffold(
          backgroundColor: appTheme.bgDark,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_controller.error != null) {
      return ResponsiveContainer(
        backgroundColor: appTheme.bgDark,
        child: Scaffold(
          backgroundColor: appTheme.bgDark,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Error: ${_controller.error}',
                  style: AppFont.secondaryTextStyle(
                    context,
                    color: appTheme.danger,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _navigateToMain,
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _controller.currentQuestion;
    if (question == null) {
      return ResponsiveContainer(
        backgroundColor: appTheme.bgDark,
        child: Scaffold(
          backgroundColor: appTheme.bgDark,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleLeave();
      },
      child: ResponsiveContainer(
        backgroundColor: appTheme.bgDark,
        child: Scaffold(
          backgroundColor: appTheme.bgDark,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Main content
              Column(
                children: [
                  // Header with streak and timer
                  _buildHeader(context, appTheme),
                  // Question card area
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 24),
                        child: _buildQuestionCard(context, appTheme),
                      ),
                    ),
                  ),
                ],
              ),
              // Leave button
              LeaveButtonOverlay(
                iconColor: appTheme.border,
                splashColor: appTheme.borderMuted,
                onPressed: _handleLeave,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppTheme appTheme) {
    final minutes =
        _controller.timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _controller.timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
    final timeText = '$minutes:$seconds';

    // Timer color based on time left
    final Color timerColor;
    if (_controller.timeLeft.inSeconds <= 10) {
      timerColor = appTheme.danger;
    } else if (_controller.timeLeft.inSeconds <= 20) {
      timerColor = appTheme.warning;
    } else {
      timerColor = appTheme.text;
    }

    return Container(
      padding: const EdgeInsets.only(top: 48, left: 16, right: 16, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Streak display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Streak',
                style: AppFont.secondaryTextStyle(
                  context,
                  fontSize: 12,
                  color: appTheme.textMuted,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${_controller.currentStreak}',
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: appTheme.text,
                    ),
                  ),
                  Text(
                    ' / ${_controller.bestStreak}',
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: appTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Timer display (only show if not submitted)
          if (!_controller.isSubmitted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: timerColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                timeText,
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: timerColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Convert backend vote int (-1, 0, 1) to VoteState enum.
  VoteState _mapVoteVerdict(int vote) {
    switch (vote) {
      case 1:
        return VoteState.upvoted;
      case -1:
        return VoteState.downvoted;
      default:
        return VoteState.none;
    }
  }

  Widget _buildQuestionCard(BuildContext context, AppTheme appTheme) {
    final question = _controller.currentQuestion!;
    final isSubmitted = _controller.isSubmitted;
    final answerResponse = _controller.answerResponse;

    // Determine colors based on pass/fail
    Color? revealedColor;
    if (isSubmitted && answerResponse != null) {
      revealedColor =
          answerResponse.passed ? appTheme.success : appTheme.danger;
    }

    // Determine paneState for button
    final QuestionPaneState paneState;
    if (!isSubmitted) {
      paneState = QuestionPaneState.started;
    } else {
      paneState = QuestionPaneState.finished;
    }

    // If passed, show Next; if failed, show Finish (isLast=true triggers Finish label)
    final bool isLast = isSubmitted && !(answerResponse?.passed ?? true);

    // boolean for if ad save is available
    final bool adSaveAvailable = isLast && _controller.canUseAdSave;

    // Custom finish button label when ad save is available
    final String? finishButtonLabel = adSaveAvailable ? 'Save Streak 🎬' : null;

    // Compute acceptable range bounds for scale highlighting (survival mode only)
    AnswerValue? acceptableRangeLower;
    AnswerValue? acceptableRangeUpper;
    if (isSubmitted && answerResponse != null) {
      final correctAnswer = answerResponse.convertedCorrectAnswer;
      final p50Ratio = answerResponse.p50Ratio;
      // Get the raw value of the correct answer
      final correctRaw = correctAnswer.rawValue ??
          (correctAnswer.number *
                  _getOmMultiplier(correctAnswer.orderOfMagnitude))
              .toDouble();
      // Compute bounds: [correct / ratio, correct * ratio]
      final lowerRaw = correctRaw / p50Ratio;
      final upperRaw = correctRaw * p50Ratio;
      // Clamp to scale bounds (1 to 999e12)
      final clampedLower = lowerRaw.clamp(1.0, 999e12);
      final clampedUpper = upperRaw.clamp(1.0, 999e12);
      // Decompose to AnswerValue for the scale widget
      acceptableRangeLower = decomposeNumber(clampedLower, correctAnswer.unit);
      acceptableRangeUpper = decomposeNumber(clampedUpper, correctAnswer.unit);
    }

    return GameCard(
      questionText: question.text,
      tags: [
        if (_controller.getCategorySlug() != null)
          _controller.getCategorySlug()!,
        if (_controller.getDifficultySlug() != null)
          _controller.getDifficultySlug()!,
        if (_controller.getYearSlug() != null) _controller.getYearSlug()!,
      ],
      currentAnswer: _controller.userAnswer,
      submittedAnswer: isSubmitted ? _controller.userAnswer : null,
      unitOptions: _controller.unitOptions,
      units: _controller.unitAbbreviations,
      currentLocale: _controller.currentLocale,
      onAnswerChanged: isSubmitted ? (_) {} : _controller.onAnswerChanged,
      onLocaleChanged: _controller.onLocaleChanged,
      editable: !isSubmitted,
      revealedAnswer:
          isSubmitted ? answerResponse?.convertedCorrectAnswer : null,
      revealedColor: revealedColor,
      unitTapeController: _controller.unitTapeController,
      // Feedback (like widget) visibility
      showFeedback: isSubmitted,
      // Vote state and callbacks
      initialLikes: question.upvotes,
      initialVoteState: _mapVoteVerdict(question.userVote),
      onUpvote: _controller.onUpvote,
      onDeUpvote: _controller.onDeUpvote,
      onDownvote: _controller.onDownvote,
      onDeDownvote: _controller.onDeDownvote,

      // AI overview
      paragraph: isSubmitted ? answerResponse?.aiOverview : null,
      // Button props (using paneState for GameCard's internal button)
      paneState: paneState,
      isLast: isLast,
      isHost: true, // Survival mode: player is always in control
      isCurrentQuestion: true, // Single question at a time
      onSubmit: _handleSubmit,
      onNext: _handleNext,
      // Acceptable range highlighting (survival mode)
      acceptableRangeLower: acceptableRangeLower,
      acceptableRangeUpper: acceptableRangeUpper,
      // Custom finish button label for ad save
      finishButtonLabel: finishButtonLabel,
      // Custom button colors for ad save
      mainButtonBackgroundColor: adSaveAvailable ? appTheme.secondary : null,
      mainButtonShadowColor: adSaveAvailable ? appTheme.secondaryMuted : null,
    );
  }

  /// Get the multiplier for an order of magnitude symbol.
  double _getOmMultiplier(String om) {
    switch (om) {
      case 'K':
        return 1e3;
      case 'M':
        return 1e6;
      case 'B':
        return 1e9;
      case 'T':
        return 1e12;
      default:
        return 1.0;
    }
  }
}
