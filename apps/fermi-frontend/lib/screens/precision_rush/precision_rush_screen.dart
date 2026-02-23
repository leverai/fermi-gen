import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/screens/precision_rush/precision_rush_screen_controller.dart';
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
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/answer_format.dart';
import 'package:fermi_frontend/services/rate_app_service.dart';

/// Precision Rush mode screen - fixed 6 questions with TAS scoring.
class PrecisionRushScreen extends StatefulWidget {
  final bool withAd;

  const PrecisionRushScreen({
    super.key,
    this.withAd = false,
  });

  @override
  State<PrecisionRushScreen> createState() => _PrecisionRushScreenState();
}

class _PrecisionRushScreenState extends State<PrecisionRushScreen> {
  late PrecisionRushScreenController _controller;
  bool _isPAPopupPending = false;
  bool _isShowingLeaveDialog = false;

  @override
  void initState() {
    super.initState();
    final apiService = context.read<ApiService>();
    final authService = context.read<AuthService>();
    final preloadService = context.read<PreloadService>();

    _controller = PrecisionRushScreenController(
      apiService: apiService,
      userLocale: authService.locale ?? 'US',
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
    if (_controller.isSubmitted) {
      _navigateToMain();
      return;
    }

    if (_isShowingLeaveDialog) return;
    _isShowingLeaveDialog = true;

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
    if (_isPAPopupPending) return;

    if (_controller.isFinal) {
      _navigateToMain();
    } else {
      await _controller.requestNext();
    }
  }

  Future<void> _showPACardPopup() async {
    final answerResponse = _controller.answerResponse;
    if (answerResponse == null) return;

    final percentile = answerResponse.percentile;
    if (PACard.getTierForPercentile(percentile) == null) return;

    final question = _controller.currentQuestion;
    if (question == null) return;

    final userAnswerValue = answerResponse.userAnswer;
    final formattedUserAnswer = _formatAnswerWithUnit(
      userAnswerValue,
      _controller.getUnitAbbreviationFromId(userAnswerValue.unit),
    );

    final correctAnswerValue = answerResponse.convertedCorrectAnswer;
    final formattedCorrectAnswer = _formatAnswerWithUnit(
      correctAnswerValue,
      _controller.getUnitAbbreviationFromId(correctAnswerValue.unit),
    );

    setState(() => _isPAPopupPending = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _isPAPopupPending = false);

    if (!mounted) return;

    final String mainLabel = _controller.isFinal ? 'Done' : 'Next';

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

    final tier = PACard.getTierForPercentile(percentile);
    if (tier == PAChiermontTier.top1 ||
        tier == PAChiermontTier.top5 ||
        tier == PAChiermontTier.top10) {
      await RateAppService.instance.maybePromptReview();
    }
  }

  String _formatAnswerWithUnit(AnswerValue value, String unitAbbreviation) {
    return formatAnswerValue(value.copyWith(unit: unitAbbreviation));
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
              Column(
                children: [
                  _buildHeader(context, appTheme),
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

    final Color timerColor;
    if (_controller.timeLeft.inSeconds <= 10) {
      timerColor = appTheme.danger;
    } else if (_controller.timeLeft.inSeconds <= 20) {
      timerColor = appTheme.warning;
    } else {
      timerColor = appTheme.text;
    }

    final Color prColor =
        (appTheme as dynamic).precisionRush ?? const Color(0xFF00ADB5);

    return Container(
      padding: const EdgeInsets.only(top: 48, left: 16, right: 16, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question',
                  style: AppFont.secondaryTextStyle(
                    context,
                    fontSize: 12,
                    color: appTheme.textMuted,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_controller.questionNumber}',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: appTheme.text,
                      ),
                    ),
                    Text(
                      ' / ${_controller.totalQuestions}',
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
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Score',
                  style: AppFont.secondaryTextStyle(
                    context,
                    fontSize: 12,
                    color: appTheme.textMuted,
                  ),
                ),
                Text(
                  formatNumberWithCommas(_controller.totalTas),
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: prColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _controller.isSubmitted
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Text(
                        '+${formatNumberWithCommas(_controller.currentTas)}',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: prColor,
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
            ),
          ),
        ],
      ),
    );
  }

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
    final prColor =
        (appTheme as dynamic).precisionRush ?? const Color(0xFF00ADB5);
    final prColorMuted = (appTheme as dynamic).precisionRushMuted ??
        const Color(0xFF00ADB5).withOpacity(0.5);

    final revealedAnswerValue = isSubmitted
        ? (answerResponse?.convertedCorrectAnswer ??
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''))
        : null;

    final QuestionPaneState paneState;
    if (!isSubmitted) {
      paneState = QuestionPaneState.started;
    } else {
      paneState = QuestionPaneState.finished;
    }

    final bool isLast = isSubmitted && _controller.isFinal;
    const String finishButtonLabel = 'Done';

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
      revealedAnswer: revealedAnswerValue,
      revealedColor: isSubmitted ? prColor : null,
      unitTapeController: _controller.unitTapeController,
      showFeedback: isSubmitted,
      initialLikes: question.upvotes,
      initialVoteState: _mapVoteVerdict(question.userVote),
      onUpvote: _controller.onUpvote,
      onDeUpvote: _controller.onDeUpvote,
      onDownvote: _controller.onDownvote,
      onDeDownvote: _controller.onDeDownvote,
      paragraph: isSubmitted ? answerResponse?.aiOverview : null,
      paneState: paneState,
      isLast: isLast,
      isHost: true,
      isCurrentQuestion: true,
      onSubmit: _handleSubmit,
      onNext: _handleNext,
      finishButtonLabel: finishButtonLabel,
      mainButtonBackgroundColor: prColor,
      mainButtonShadowColor: prColorMuted,
    );
  }
}
