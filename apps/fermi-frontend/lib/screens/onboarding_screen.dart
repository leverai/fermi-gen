import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:fermi_frontend/screens/question_v2/question_screen_v2.dart';
import 'package:fermi_frontend/services/demo/onboarding_realtime.dart';
import 'package:fermi_frontend/services/preload_service.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/styled_dialog.dart';

/// Onboarding screen that guides first-time users through answering a question.
///
/// Uses tutorial_coach_mark to highlight UI elements step by step.
/// Each step displays a dialog with Next and Skip buttons for clear navigation.
/// Users can progress through the tutorial or skip to end the tutorial sequence
/// and interact with the widgets directly.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.testMode = false,
    this.preloadService,
  });

  /// If true, don't persist the onboarding_seen flag (for testing)
  final bool testMode;

  /// Optional preload service to ensure data is being fetched in background
  final PreloadService? preloadService;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingRealtime _realtime;
  TutorialCoachMark? _tutorialCoachMark;
  bool _hasStartedInitialTutorial = false;
  bool _blockInteractions = true; // Block during initial layout
  bool _isEndingTutorial = false; // Flag to prevent recursion
  bool _isDisposing = false; // Flag to prevent setState during disposal

  // GlobalKeys for tutorial targets (passed through to child widgets)
  final GlobalKey _questionWidgetKey = GlobalKey();
  final GlobalKey _unitLabelKey = GlobalKey();
  final GlobalKey _answerScaleKey = GlobalKey();

  // Key to access the QuestionScreenV2 wrapper
  final GlobalKey<_QuestionScreenWrapperState> _questionScreenKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _realtime = OnboardingRealtime(initialLocale: 'US');

    // Ensure preloading is happening in the background
    widget.preloadService?.preload();

    // Start tutorial after first frame + small delay for layout to settle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_hasStartedInitialTutorial) {
          _startInitialTutorial();
        }
      });
    });
  }

  @override
  void dispose() {
    // Set flag to prevent setState during disposal
    _isDisposing = true;
    // Clean up tutorial overlay if still showing
    _tutorialCoachMark?.skip();
    super.dispose();
  }

  /// Handles skip button press - dismisses tutorial overlay but stays on onboarding screen
  void _handleSkip() {
    _endTutorial();
  }

  /// Ends the tutorial sequence without navigating away - allows user to interact with widgets.
  ///
  /// [skipTutorial] - If true, calls TutorialCoachMark.skip() to dismiss the overlay.
  ///                  Set to false when called from the onSkip callback to prevent recursion
  ///                  (since the library already calls skip() internally).
  void _endTutorial({bool skipTutorial = true}) {
    // Prevent infinite recursion if already ending tutorial
    if (_isEndingTutorial) return;

    // Don't update state if widget is being disposed
    if (_isDisposing) return;

    _isEndingTutorial = true;

    // Only call skip() if requested (not when called from onSkip callback)
    if (skipTutorial && _tutorialCoachMark != null) {
      _tutorialCoachMark!.skip();
    }

    // Ensure interactions are enabled so user can play with widgets
    if (mounted && !_isDisposing) {
      setState(() {
        _blockInteractions = false;
        _isEndingTutorial = false; // Reset flag after state update
      });
    } else {
      _isEndingTutorial = false; // Reset flag if not mounted or disposing
    }
  }

  void _startInitialTutorial() {
    if (!mounted) return;
    setState(() {
      _hasStartedInitialTutorial = true;
      _blockInteractions = false; // Allow interactions once tutorial starts
    });

    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final targets = <TargetFocus>[
      // Step 1: Question widget
      TargetFocus(
        identify: 'question',
        keyTarget: _questionWidgetKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 50,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _TutorialDialog(
                key: const ValueKey('question-card'),
                message: 'Question',
                secondaryMessage: null,
                foregroundColor: appTheme.primary,
                stepIndex: 1,
                totalSteps: 3,
                onNext: () => controller.next(),
                onSkip: _handleSkip,
              );
            },
          ),
        ],
      ),
      // Step 3: Answer accuracy scale
      TargetFocus(
        identify: 'answer-scale',
        keyTarget: _answerScaleKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 30,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _TutorialDialog(
                key: const ValueKey('answer-scale-card'),
                message: 'Answer',
                secondaryMessage: 'Slide to answer',
                foregroundColor: appTheme.primary,
                stepIndex: 2,
                totalSteps: 3,
                onNext: () => controller.next(),
                onSkip: _handleSkip,
              );
            },
          ),
        ],
      ),
      // Step 2: Unit selector
      TargetFocus(
        identify: 'unit-selector',
        keyTarget: _unitLabelKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 30,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _TutorialDialog(
                key: const ValueKey('unit-card'),
                message: 'Unit',
                secondaryMessage: 'Imperial and Metric units',
                foregroundColor: appTheme.primary,
                stepIndex: 3,
                totalSteps: 3,
                onNext: () => controller.next(),
                onSkip: _handleSkip,
              );
            },
          ),
        ],
      )
    ];

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      // Skip focus-out animation for faster transitions (bubble appears to move directly)
      unFocusAnimationDuration: const Duration(milliseconds: 10),
      // Faster focus-in animation (still smooth but quicker)
      focusAnimationDuration: const Duration(milliseconds: 500),
      // Disable pulse animation for cleaner, faster feel
      pulseEnable: false,
      onFinish: () {
        // Tutorial completed successfully - ensure interactions are enabled
        // Note: onFinish is called when user completes all steps via Next buttons
        if (mounted && !_isDisposing) {
          setState(() {
            _blockInteractions = false;
          });
        }
      },
      onSkip: () {
        // User skipped tutorial - end tutorial but stay on onboarding screen
        // Pass skipTutorial: false to prevent recursion (skip() already called by library)
        _endTutorial(skipTutorial: false);
        return true;
      },
    );

    _tutorialCoachMark!.show(context: context);
  }

  /// Temporarily dismisses the tutorial overlay to allow interactions with dialogs.
  ///
  /// Called before showing dialogs (like the leave dialog) so they can be interacted with.
  /// The tutorial will remain dismissed after this is called.
  void _dismissTutorialForDialog() {
    if (_tutorialCoachMark != null && !_isDisposing) {
      _tutorialCoachMark!.skip();
      // Mark tutorial as ended so it doesn't interfere with dialog interactions
      if (mounted && !_isDisposing) {
        setState(() {
          _blockInteractions = false;
        });
      }
    }
  }

  /// Exits the onboarding screen and navigates to the main screen.
  ///
  /// Called when the user completes answering the question (via QuestionScreenV2's
  /// onFinish callback). Marks onboarding as seen and navigates to main screen.
  /// User is already authenticated anonymously, so we can go directly to main.
  void _exitOnboarding() async {
    // Navigate to startup auth screen choice
    // User is already authenticated anonymously, so we just move to the choice screen
    Navigator.pushReplacementNamed(context, '/startup-auth');
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final ThemeData baseTheme = Theme.of(context);
    final ThemeData themedData = baseTheme.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        baseTheme.extension<AppFont>() ??
            const AppFont(primaryFamily: 'Barlow', useGoogleFonts: true),
        appTheme,
      ],
    );

    return Theme(
      data: themedData,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: IgnorePointer(
          ignoring: _blockInteractions,
          child: _QuestionScreenWrapper(
            key: _questionScreenKey,
            realtime: _realtime,
            questionWidgetKey: _questionWidgetKey,
            unitLabelKey: _unitLabelKey,
            answerScaleKey: _answerScaleKey,
            onExit: _exitOnboarding,
            onDismissTutorial: _dismissTutorialForDialog,
          ),
        ),
      ),
    );
  }
}

/// Wrapper around QuestionScreenV2 that will pass keys through to child widgets.
class _QuestionScreenWrapper extends StatefulWidget {
  const _QuestionScreenWrapper({
    super.key,
    required this.realtime,
    required this.questionWidgetKey,
    required this.unitLabelKey,
    required this.answerScaleKey,
    required this.onExit,
    required this.onDismissTutorial,
  });

  final OnboardingRealtime realtime;
  final GlobalKey questionWidgetKey;
  final GlobalKey unitLabelKey;
  final GlobalKey answerScaleKey;
  final VoidCallback onExit;
  final VoidCallback onDismissTutorial;

  @override
  State<_QuestionScreenWrapper> createState() => _QuestionScreenWrapperState();
}

class _QuestionScreenWrapperState extends State<_QuestionScreenWrapper> {
  @override
  Widget build(BuildContext context) {
    return QuestionScreenV2(
      gameId: 'onboarding',
      realtime: widget.realtime,
      questionCount: 1,
      isHost: true,
      showLeaveButton: false, // Hide leave button in onboarding
      questionWidgetKey: widget.questionWidgetKey,
      unitKey: widget.unitLabelKey, // Map unitLabelKey to unitKey
      answerScaleKey: widget.answerScaleKey,
      onFinish: widget.onExit, // Handle Finish button click
      onBeforeShowDialog:
          widget.onDismissTutorial, // Dismiss tutorial before showing dialogs
    );
  }
}

/// Tutorial dialog widget displayed for each onboarding step.
///
/// Shows a primary message, optional secondary message, and two action buttons:
/// - Next: Advances to the next tutorial step
/// - Skip: Ends the tutorial sequence but keeps user on onboarding screen
class _TutorialDialog extends StatelessWidget {
  const _TutorialDialog({
    super.key,
    required this.message,
    this.secondaryMessage,
    required this.foregroundColor,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  final String message;
  final String? secondaryMessage;
  final Color foregroundColor;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return StyledDialog(
      message: message,
      secondaryMessage: secondaryMessage,
      primaryButtonLabel: stepIndex == totalSteps
          ? 'Done! ($stepIndex/$totalSteps)'
          : 'Next ($stepIndex/$totalSteps)',
      primaryButtonColor: foregroundColor,
      onPrimaryPressed: onNext,
      secondaryButtonLabel: 'Skip',
      onSecondaryPressed: onSkip,
      showAsDialog: false, // Used as content widget, not standalone dialog
      primaryButtonWidget: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: stepIndex == totalSteps ? 'Done! ' : 'Next ',
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: appTheme.bgLight,
              ).copyWith(letterSpacing: 0.2),
            ),
            TextSpan(
              text: '($stepIndex/$totalSteps)',
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: appTheme.bgLight,
              ).copyWith(letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}
