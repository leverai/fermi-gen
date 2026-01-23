// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/feedback_service.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/question_answer_card.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';
import 'package:fermi_frontend/widgets/styled_dialog.dart';
import 'package:fermi_frontend/screens/daily_question/widgets/dq_results_bottom_sheet.dart';
import 'package:fermi_frontend/widgets/share_button.dart';
import 'package:share_plus/share_plus.dart';

/// Unified Daily Question screen for both taking questions and viewing results.
///
/// When [questionDate] is null or matches today's date, shows the active question.
/// When [questionDate] is a past date, shows results with expanded bottom sheet.
class DailyQuestionScreen extends StatefulWidget {
  /// Optional date for viewing past DQ results (YYYY-MM-DD format).
  /// If null, shows today's active DQ.
  final String? questionDate;

  /// Whether this is a post-take (taking an older closed DQ).
  /// If true, uses post-take API endpoints.
  final bool isPostTake;

  /// Whether access was granted via watching an ad (bypasses Pro check).
  final bool withAd;

  const DailyQuestionScreen({
    super.key,
    this.questionDate,
    this.isPostTake = false,
    this.withAd = false,
  });

  @override
  State<DailyQuestionScreen> createState() => _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends State<DailyQuestionScreen> {
  DQQuestionResponse? _question;
  bool _isLoading = true;
  bool _isSubmitted = false;
  bool _isPastDate = false;
  bool _submittedWithoutQuestion =
      false; // True when user returns after submission
  String?
      _effectiveDate; // Frozen on init to prevent changing when controller updates
  AnswerValue _currentAnswer =
      const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');

  // For post-take: track when user started to send with submission
  DateTime? _postTakeStartedAt;

  // Unit selection state
  String _currentLocale = 'US';
  List<String> _unitAbbreviations = [];
  Map<String, String> _unitOptions = {}; // name -> abbreviation
  Map<String, String> _unitAbbreviationToId = {}; // abbreviation -> id

  // Timer
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  // Results data for reveal animation
  DQResultsResponse? _resultsData;

  // Unit tape controller for managing indicators
  final UnitTapeController _unitTapeController = UnitTapeController();

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    final controller = context.read<DailyQuestionController>();
    final todayDate = controller.todayDate;

    // Determine and freeze effective date for this view
    // This prevents the date from changing when controller.todayDate updates
    final effectiveDate = widget.questionDate ?? todayDate;
    _effectiveDate = effectiveDate;

    // Determine if this is a past date view (not today)
    _isPastDate = effectiveDate != null && effectiveDate != todayDate;

    // Handle post-take flow (taking an older closed DQ)
    if (widget.isPostTake) {
      await _startPostTakeQuestion();
      return;
    }

    if (_isPastDate) {
      // For past dates, load results to display QuestionAnswerCard with user's answer
      setState(() {
        _isSubmitted = true; // Lock inputs
      });
      // Load results data which contains question text, user answer, and correct answer
      await _loadResults();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      // Today's date - check if already submitted
      final hasParticipated = controller.hasParticipatedToday;
      if (hasParticipated) {
        // User has already submitted
        final resultsReady = controller.todayDocument?.resultsReady ?? false;
        setState(() {
          _isLoading = false;
          _isSubmitted = true;
          _submittedWithoutQuestion = true;
        });
        // If results are already ready, load them immediately so QuestionAnswerCard
        // can display with reveal animation
        if (resultsReady) {
          _loadResults();
        }
      } else {
        // Start the question
        await _startQuestion();
      }
    }
  }

  Future<void> _startQuestion() async {
    final controller = context.read<DailyQuestionController>();
    final authService = context.read<AuthService>();

    try {
      final question = await controller.startQuestion();

      // Get user's locale preference, default to 'US'
      final userLocale = authService.locale ?? 'US';

      setState(() {
        _question = question;
        _isLoading = false;
        _currentLocale = userLocale;

        // Initialize unit options from question
        _initializeUnits(question.units, userLocale);

        // Start Timer
        final now = DateTime.now();
        final deadline = question.answerDeadline;
        // print('[DQ] Timer init - Now: $now, Deadline: $deadline');
        if (deadline.isAfter(now)) {
          _timeLeft = deadline.difference(now);
          // print('[DQ] Starting timer with ${_timeLeft.inSeconds} seconds');
          _startTimer();
        } else {
          // print('[DQ] WARNING: Deadline already passed! Cannot start timer.');
          _timeLeft = Duration.zero;
        }
      });
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().toLowerCase();
        // Handle race condition: DQ transitioned from ACTIVE to CLOSED while navigating.
        // If backend says "not yet active", the DQ was closed - retry as post-take.
        if (errorMsg.contains('not yet active') ||
            errorMsg.contains('window is closed')) {
          await _startPostTakeQuestion();
          return;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        context.go('/main');
      }
    }
  }

  /// Start a post-take for a closed daily question.
  Future<void> _startPostTakeQuestion() async {
    final authService = context.read<AuthService>();
    final service = context.read<DailyQuestionService>();

    try {
      final effectiveDate = _effectiveDate;
      if (effectiveDate == null) {
        throw Exception('No date available for post-take');
      }

      final question = await service.startPostTake(
        effectiveDate,
        withAd: widget.withAd,
      );

      // Get user's locale preference, default to 'US'
      final userLocale = authService.locale ?? 'US';

      // Track when user started for submission deadline validation
      final startedAt = DateTime.now().toUtc();

      setState(() {
        _question = question;
        _isLoading = false;
        _currentLocale = userLocale;
        _postTakeStartedAt = startedAt;

        // Initialize unit options from question
        _initializeUnits(question.units, userLocale);

        // Start Timer (30 seconds for post-take)
        _timeLeft = Duration(seconds: question.secondsToAnswer.toInt());
        _startTimer();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        context.go('/main');
      }
    }
  }

  void _initializeUnits(
    Map<String, List<Map<String, String>>>? units,
    String locale,
  ) {
    if (units == null || units.isEmpty) {
      _unitAbbreviations = [];
      _unitOptions = {};
      _unitAbbreviationToId = {};
      return;
    }

    // Get units for the current locale
    final localeUnits = units[locale.toUpperCase()] ?? units['US'] ?? [];

    if (localeUnits.isEmpty) {
      _unitAbbreviations = [];
      _unitOptions = {};
      _unitAbbreviationToId = {};
      return;
    }

    // Build abbreviations list and options map
    _unitAbbreviations = localeUnits
        .map((u) => u['abbreviation'] ?? '')
        .where((a) => a.isNotEmpty)
        .toList();

    _unitOptions = {
      for (final u in localeUnits)
        if (u['name'] != null && u['abbreviation'] != null)
          u['name']!: u['abbreviation']!
    };

    // Build abbreviation -> id map for API submission
    _unitAbbreviationToId = {
      for (final u in localeUnits)
        if (u['abbreviation'] != null && u['id'] != null)
          u['abbreviation']!: u['id']!
    };

    // Default to largest unit (last in ladder)
    if (_unitAbbreviations.isNotEmpty) {
      final defaultUnit = _unitAbbreviations.last;
      _currentAnswer = _currentAnswer.copyWith(unit: defaultUnit);
    }
  }

  void _onLocaleChanged(String newLocale) {
    if (_question?.units == null) return;

    setState(() {
      _currentLocale = newLocale;
      _initializeUnits(_question!.units, newLocale);
    });

    // Persist locale change to backend
    final apiService = context.read<ApiService>();
    apiService.setUserLocale(locale: newLocale);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        // print('[DQ] Timer cancelled - widget not mounted');
        timer.cancel();
        return;
      }

      // print(
      //     '[DQ] Timer tick - Time left: ${_timeLeft.inSeconds}s, isSubmitted: $_isSubmitted');

      setState(() {
        if (_timeLeft.inSeconds > 0) {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        }
      });

      // Trigger auto-submit AFTER setState completes, when time reaches 0
      if (_timeLeft.inSeconds <= 0 && !_isSubmitted) {
        // print('[DQ] ⏰ AUTO-SUBMIT TRIGGERED - Time expired!');
        _timer?.cancel();
        _autoSubmit();
      }
    });
  }

  Future<void> _autoSubmit() async {
    // print(
    //     '[DQ] _autoSubmit called - mounted: $mounted, isSubmitted: $_isSubmitted');
    if (!mounted || _isSubmitted) {
      // print('[DQ] _autoSubmit early return - guards failed');
      return;
    }
    // print('[DQ] Showing "Time\'s up" snackbar...');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Time\'s up! Submitting your answer...'),
        duration: Duration(seconds: 1),
      ),
    );
    // print('[DQ] Calling _submit()...');
    await _submit();
  }

  Future<void> _submit() async {
    // print('[DQ] _submit called - isSubmitted: $_isSubmitted');
    if (_isSubmitted) {
      // print('[DQ] _submit early return - already submitted');
      return;
    }

    // Handle post-take submission differently
    if (widget.isPostTake) {
      await _submitPostTake();
      return;
    }

    final controller = context.read<DailyQuestionController>();
    try {
      // print('[DQ] Submitting answer to backend...');
      // Translate abbreviation to ID before submitting
      final unitId = _currentAnswer.unit.isNotEmpty
          ? (_unitAbbreviationToId[_currentAnswer.unit] ?? _currentAnswer.unit)
          : '';
      final answerToSubmit = _currentAnswer.copyWith(unit: unitId);
      // print('[DQ] Translated unit: ${_currentAnswer.unit} -> $unitId');
      await controller.submitAnswer(answerToSubmit);
      if (mounted) {
        // print(
        //     '[DQ] Answer submitted successfully, cancelling timer and updating state');
        _timer?.cancel();
        setState(() {
          _isSubmitted = true;
          _submittedWithoutQuestion = true;
          _question = null; // Clear to trigger waiting placeholder UI
        });
        // Hide unit tape indicators immediately after submission
        _unitTapeController.setRevealed(
            true, const Duration(milliseconds: 600));
      }
    } catch (e) {
      // print('[DQ] Error submitting answer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error submitting: $e')));
      }
    }
  }

  /// Submit a post-take answer and get immediate results.
  Future<void> _submitPostTake() async {
    final service = context.read<DailyQuestionService>();
    final effectiveDate = _effectiveDate;
    final startedAt = _postTakeStartedAt;

    if (effectiveDate == null || startedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Missing post-take data')),
      );
      return;
    }

    try {
      // Translate abbreviation to ID before submitting
      final unitId = _currentAnswer.unit.isNotEmpty
          ? (_unitAbbreviationToId[_currentAnswer.unit] ?? _currentAnswer.unit)
          : '';
      final answerToSubmit = _currentAnswer.copyWith(unit: unitId);

      final response = await service.submitPostTakeAnswer(
        effectiveDate,
        answerToSubmit,
        startedAt,
        withAd: widget.withAd,
      );

      if (mounted) {
        _timer?.cancel();
        setState(() {
          _isSubmitted = true;
          // Convert post-take response to standard results format
          _resultsData = response.toDQResultsResponse();
          _currentAnswer = response.userAnswer;
          _submittedWithoutQuestion = false; // Show question card with reveal
        });
        // Hide unit tape indicators
        _unitTapeController.setRevealed(
            true, const Duration(milliseconds: 600));

        // Refresh archive to update participation status and mark as seen
        // Since results are shown immediately after post-take, mark as seen
        final controller = context.read<DailyQuestionController>();
        controller.markResultsSeen(effectiveDate);
        await controller.refreshArchiveAndSubscribe();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error submitting: $e')));
      }
    }
  }

  String get _formattedTime {
    final minutes =
        _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  DQResultsHandleStatus _getResultsStatus() {
    final controller = context.watch<DailyQuestionController>();
    final effectiveDate = _effectiveDate;

    if (effectiveDate == null) {
      return DQResultsHandleStatus.pending;
    }

    // Check if results have been seen
    if (controller.hasUnseenResults(effectiveDate) == false &&
        _isSubmitted &&
        (controller.todayDocument?.resultsReady ?? false)) {
      // User has seen results (not in unseen set, but has participated)
      return DQResultsHandleStatus.seen;
    }

    // Check if results are ready
    final isToday = effectiveDate == controller.todayDate;
    if (isToday) {
      final resultsReady = controller.todayDocument?.resultsReady ?? false;
      if (resultsReady) {
        return controller.hasUnseenResults(effectiveDate)
            ? DQResultsHandleStatus.ready
            : DQResultsHandleStatus.seen;
      }
      return DQResultsHandleStatus.pending;
    } else {
      // Past dates always have results ready
      return DQResultsHandleStatus.seen;
    }
  }

  void _onResultsViewed() {
    final controller = context.read<DailyQuestionController>();
    final effectiveDate = _effectiveDate;
    if (effectiveDate != null) {
      controller.markResultsSeen(effectiveDate);
    }
  }

  /// Handle leave button press - show confirmation if not submitted
  Future<void> _handleLeave() async {
    // If already submitted, just navigate back to main
    if (_isSubmitted) {
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
          onPrimaryPressed: () => Navigator.of(context).pop(true),
          secondaryButtonLabel: 'Cancel',
          onSecondaryPressed: () => Navigator.of(context).pop(false),
          showAsDialog: true,
        );
      },
    );

    // If user confirmed, submit answer then navigate back to main
    if (confirmed == true) {
      await _submit();
      _navigateToMain();
    }
  }

  /// Navigate to main screen, handling both Navigator-pushed and GoRouter cases.
  void _navigateToMain() {
    if (!mounted) return;
    // Pop this screen from Navigator if it was pushed via MaterialPageRoute.
    // Since PreDailyQuestionScreen uses pushReplacement(), popping will go
    // directly to MainScreen, not back to the pre-DQ screen.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // Navigate to main via GoRouter
    context.go('/main');
  }

  /// Load results when they become ready
  Future<void> _loadResults() async {
    if (_resultsData != null) return;
    final effectiveDate = _effectiveDate;
    if (effectiveDate == null) return;

    try {
      final service = context.read<DailyQuestionService>();
      final results = await service.getResultsForDate(effectiveDate);
      if (mounted) {
        // Track if this is a fresh reveal (user is still on screen when results load)
        // vs returning to see already-revealed results
        final isFreshReveal = !_submittedWithoutQuestion;

        setState(() {
          _resultsData = results;
          // Update current answer display to user's submitted answer (if they participated)
          // or to the correct answer (if they didn't participate)
          if (results.userAnswer != null) {
            _currentAnswer = results.userAnswer!;
          } else if (results.correctAnswer.unit.isNotEmpty) {
            // User didn't participate - show correct answer with unit
            _currentAnswer = results.correctAnswer;
          }

          // Initialize units for the unit tape display
          // For non-participants, we only have the correct answer's unit
          final correctUnit = results.correctAnswer.unit;
          if (correctUnit.isNotEmpty && _unitAbbreviations.isEmpty) {
            // Set up minimal unit state for display (read-only mode)
            _unitAbbreviations = [correctUnit];
            _unitOptions = {correctUnit: correctUnit}; // name:abbr mapping
          }

          // Clear submittedWithoutQuestion flag so QuestionAnswerCard can display
          // with reveal animation using results.questionText
          _submittedWithoutQuestion = false;
        });

        // Hide unit tape indicators, but with different behavior:
        // - Fresh reveal: animated fade (600ms) to match reveal animation
        // - Returning to view: instant hide (0ms) since already revealed
        _unitTapeController.setRevealed(true,
            isFreshReveal ? const Duration(milliseconds: 600) : Duration.zero);
      }
    } catch (e) {
      // Ignore errors - results may not be ready yet
      // print('[DQ] Error loading results: $e');
    }
  }

  /// Get question text from either question or results data
  String? get _questionText {
    if (_question != null) return _question!.text;
    if (_resultsData != null) return _resultsData!.questionText;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final controller = context.watch<DailyQuestionController>();

    if (_isLoading) {
      return ResponsiveContainer(
        backgroundColor: appTheme.bgDark,
        child: Scaffold(
          backgroundColor: appTheme.bgDark,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // For past dates, we rely on _resultsData for question text.
    // If still loading or no data available, show loading state.
    if (_isPastDate && _question == null && _resultsData == null) {
      return ResponsiveContainer(
        backgroundColor: appTheme.bgDark,
        child: Scaffold(
          backgroundColor: appTheme.bgDark,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Determine if we have question data to show QuestionAnswerCard
    final bool hasQuestionData = _questionText != null;

    // No question loaded and no results data and not submitted - can't display anything
    if (!hasQuestionData && !_submittedWithoutQuestion) {
      return ResponsiveContainer(
        backgroundColor: appTheme.bgDark,
        child: Scaffold(
          backgroundColor: appTheme.bgDark,
          body: Stack(
            children: [
              _buildBackButton(appTheme),
              Center(
                child: Text(
                  'No question available',
                  style: AppFont.secondaryTextStyle(
                    context,
                    color: appTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool inputsEnabled = !_isSubmitted;
    final resultsStatus = _getResultsStatus();
    final showResultsSheet = _isSubmitted;

    // Load results when status changes to ready/seen
    if (resultsStatus != DQResultsHandleStatus.pending &&
        _resultsData == null) {
      _loadResults();
    }

    // Determine reveal animation values
    final bool showReveal = _resultsData != null;
    final revealedAnswer = showReveal ? _resultsData!.correctAnswer : null;
    final revealedColor = showReveal ? appTheme.success : null;
    final submittedAnswer = showReveal ? _resultsData!.userAnswer : null;
    final authService = context.read<AuthService>();

    return ResponsiveContainer(
      backgroundColor: appTheme.bgDark,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          _handleLeave();
        },
        child: Scaffold(
          backgroundColor: appTheme.bgDark,
          body: Stack(
            children: [
              // Main content
              Column(
                children: [
                  // Header with back button and timer
                  _buildHeader(appTheme, inputsEnabled),

                  // Question and input area (or waiting placeholder)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated transition between question card and waiting placeholder
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 600),
                              switchInCurve: Curves.easeOutBack,
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                              child: hasQuestionData
                                  ? QuestionAnswerCard(
                                      key: const ValueKey('question_card'),
                                      questionText: _questionText ?? '',
                                      tags: const [], // No tags for daily question
                                      currentAnswer: _currentAnswer,
                                      submittedAnswer: submittedAnswer,
                                      unitOptions: _unitOptions,
                                      units: _unitAbbreviations,
                                      currentLocale: _currentLocale,
                                      onAnswerChanged: inputsEnabled
                                          ? (val) {
                                              setState(() {
                                                _currentAnswer = val;
                                              });
                                            }
                                          : (_) {},
                                      onLocaleChanged: _onLocaleChanged,
                                      editable: inputsEnabled,
                                      revealedAnswer: revealedAnswer,
                                      revealedColor: revealedColor,
                                      unitTapeController: _unitTapeController,
                                      buttonWidget: MainButton(
                                        onPressed:
                                            inputsEnabled ? _submit : null,
                                        label: MainButtonLabel.submit,
                                      ),
                                      paragraph: _resultsData?.paragraph,
                                    )
                                  : KeyedSubtree(
                                      key:
                                          const ValueKey('waiting_placeholder'),
                                      child: _buildWaitingPlaceholder(appTheme),
                                    ),
                            ),

                            // Spacer for bottom sheet (always present to maintain centering)
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Results bottom sheet
              if (showResultsSheet)
                DQResultsBottomSheet(
                  questionDate: _effectiveDate ?? '',
                  status: resultsStatus,
                  windowEnd: controller.todayDocument?.windowEnd,
                  onResultsViewed: _onResultsViewed,
                  service: context.read<DailyQuestionService>(),
                  userDisplayName: authService.currentUser?.displayName,
                  userAvatarUrl: authService.currentUser?.picture,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Placeholder shown when user submitted but we don't have question data yet
  Widget _buildWaitingPlaceholder(AppTheme appTheme) {
    final controller = context.watch<DailyQuestionController>();
    final todayDoc = controller.todayDocument;
    // Show invite button only before DQ closes, and when we have an invite URL
    final bool canInvite = !_isPastDate && (todayDoc?.isActive ?? false);
    final String? inviteUrl = todayDoc?.inviteUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 64,
          color: appTheme.success,
        ),
        const SizedBox(height: 16),
        Text(
          'Answer Submitted',
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: appTheme.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Come back for results later.',
          style: AppFont.secondaryTextStyle(
            context,
            color: appTheme.textMuted,
          ),
        ),
        const SizedBox(height: 48),
        // Share button (after submission, before DQ closes)
        SizedBox(
            width: 200,
            child: Visibility(
              visible: canInvite,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: inviteUrl != null
                  ? ShareButton(onPressed: () => _shareInvite(inviteUrl))
                  : const SizedBox.shrink(),
            )),
      ],
    );
  }

  Widget _buildHeader(AppTheme appTheme, bool showTimer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: Icon(Icons.arrow_back, color: appTheme.border),
            onPressed: () {
              FeedbackService.instance.secondaryClick();
              _handleLeave();
            },
            tooltip: 'Leave',
          ),

          const Spacer(),

          // Timer (only when active)
          if (showTimer && !_isSubmitted)
            Text(
              _formattedTime,
              style: AppFont.secondaryTextStyle(
                context,
                fontSize: 20,
                color:
                    _timeLeft.inSeconds < 10 ? appTheme.danger : appTheme.text,
                fontWeight: FontWeight.w700,
              ),
            ),

          // Submitted indicator
          if (_isSubmitted && !_isPastDate) _buildSubmittedChip(appTheme),

          const Spacer(),

          // Invite button (REMOVED - now in _buildWaitingPlaceholder)
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// Share the DQ invite link using the OS share sheet or clipboard on web.
  Future<void> _shareInvite(String inviteUrl) async {
    // Transform localhost to 10.0.2.2 for Android emulator testing
    String urlToShare = inviteUrl;
    if (!kIsWeb && Platform.isAndroid) {
      urlToShare =
          inviteUrl.replaceFirst('http://localhost', 'http://10.0.2.2');
    }

    try {
      if (kIsWeb) {
        // Web: Copy to clipboard and show feedback
        await Clipboard.setData(ClipboardData(text: urlToShare));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite link copied.')),
          );
        }
      } else {
        // Mobile: Use native share sheet
        await Share.share(
          urlToShare,
          subject: 'Take the Daily Question with me!',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  /// Build the "Submitted" chip indicator
  Widget _buildSubmittedChip(AppTheme appTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: appTheme.success.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Submitted ✓',
        style: AppFont.secondaryTextStyle(
          context,
          fontSize: 14,
          color: appTheme.success,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBackButton(AppTheme appTheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: appTheme.text),
          onPressed: _handleLeave,
          tooltip: 'Leave',
        ),
      ),
    );
  }
}
