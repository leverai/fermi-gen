import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/screens/survival/survival_screen_controller.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/question_answer_card.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';
import 'package:fermi_frontend/widgets/styled_dialog.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:fermi_frontend/widgets/player_confetti_overlay.dart';

/// Survival mode screen - single player timed questions until failure.
class SurvivalScreen extends StatefulWidget {
  const SurvivalScreen({super.key});

  @override
  State<SurvivalScreen> createState() => _SurvivalScreenState();
}

class _SurvivalScreenState extends State<SurvivalScreen> {
  late SurvivalScreenController _controller;

  @override
  void initState() {
    super.initState();
    final apiService = context.read<ApiService>();
    final authService = context.read<AuthService>();

    _controller = SurvivalScreenController(
      apiService: apiService,
      userLocale: authService.locale ?? 'US',
    );
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

    // Show confirmation dialog
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final bool? confirmed = await showDialog<bool>(
      context: context,
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
  }

  void _navigateToMain() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    context.go('/main');
  }

  Future<void> _handleSubmit() async {
    await _controller.submitAnswer();
  }

  Future<void> _handleNext() async {
    if (_controller.passed) {
      await _controller.requestNext();
    } else {
      // Failed - finish and go back
      _navigateToMain();
    }
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
              // Confetti overlay on pass
              if (_controller.showConfetti)
                Positioned.fill(
                  child: IgnorePointer(
                    child: PlayerConfettiOverlay(
                      onComplete: _controller.clearConfetti,
                    ),
                  ),
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

    // Build button
    final Widget buttonWidget;
    if (!isSubmitted) {
      buttonWidget = MainButton(
        onPressed: _handleSubmit,
        label: MainButtonLabel.submit,
      );
    } else if (answerResponse != null) {
      buttonWidget = MainButton(
        onPressed: _handleNext,
        label: answerResponse.passed
            ? MainButtonLabel.next
            : MainButtonLabel.finish,
      );
    } else {
      buttonWidget = const SizedBox.shrink();
    }

    return QuestionAnswerCard(
      questionText: question.text,
      tags: [
        if (question.category != null) question.category!,
        if (question.difficulty != null) question.difficulty!,
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
      buttonWidget: buttonWidget,
      paragraph: isSubmitted ? answerResponse?.aiOverview : null,
    );
  }
}
