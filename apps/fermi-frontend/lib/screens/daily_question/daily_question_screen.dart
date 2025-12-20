import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/question_answer_card.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/screens/daily_question/widgets/dq_results_bottom_sheet.dart';

/// Unified Daily Question screen for both taking questions and viewing results.
///
/// When [questionDate] is null or matches today's date, shows the active question.
/// When [questionDate] is a past date, shows results with expanded bottom sheet.
class DailyQuestionScreen extends StatefulWidget {
  /// Optional date for viewing past DQ results (YYYY-MM-DD format).
  /// If null, shows today's active DQ.
  final String? questionDate;

  const DailyQuestionScreen({super.key, this.questionDate});

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

  // Unit selection state
  String _currentLocale = 'US';
  List<String> _unitAbbreviations = [];
  Map<String, String> _unitOptions = {}; // name -> abbreviation

  // Timer
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

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

    if (_isPastDate) {
      // For past dates, just show the results (no question to answer)
      setState(() {
        _isLoading = false;
        _isSubmitted = true; // Lock inputs
      });
    } else {
      // Today's date - check if already submitted
      final hasParticipated = controller.hasParticipatedToday;
      if (hasParticipated) {
        // User has already submitted - show submitted view without question
        setState(() {
          _isLoading = false;
          _isSubmitted = true;
          _submittedWithoutQuestion =
              true; // Special flag for submitted-today state
        });
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
        print('[DQ] Timer init - Now: $now, Deadline: $deadline');
        if (deadline.isAfter(now)) {
          _timeLeft = deadline.difference(now);
          print('[DQ] Starting timer with ${_timeLeft.inSeconds} seconds');
          _startTimer();
        } else {
          print('[DQ] WARNING: Deadline already passed! Cannot start timer.');
          _timeLeft = Duration.zero;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        Navigator.of(context).pop();
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
      return;
    }

    // Get units for the current locale
    final localeUnits = units[locale.toUpperCase()] ?? units['US'] ?? [];

    if (localeUnits.isEmpty) {
      _unitAbbreviations = [];
      _unitOptions = {};
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
        print('[DQ] Timer cancelled - widget not mounted');
        timer.cancel();
        return;
      }

      print(
          '[DQ] Timer tick - Time left: ${_timeLeft.inSeconds}s, isSubmitted: $_isSubmitted');

      setState(() {
        if (_timeLeft.inSeconds > 0) {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        }
      });

      // Trigger auto-submit AFTER setState completes, when time reaches 0
      if (_timeLeft.inSeconds <= 0 && !_isSubmitted) {
        print('[DQ] ⏰ AUTO-SUBMIT TRIGGERED - Time expired!');
        _timer?.cancel();
        _autoSubmit();
      }
    });
  }

  Future<void> _autoSubmit() async {
    print(
        '[DQ] _autoSubmit called - mounted: $mounted, isSubmitted: $_isSubmitted');
    if (!mounted || _isSubmitted) {
      print('[DQ] _autoSubmit early return - guards failed');
      return;
    }
    print('[DQ] Showing "Time\'s up" snackbar...');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Time\'s up! Submitting your answer...'),
        duration: Duration(seconds: 1),
      ),
    );
    print('[DQ] Calling _submit()...');
    await _submit();
  }

  Future<void> _submit() async {
    print('[DQ] _submit called - isSubmitted: $_isSubmitted');
    if (_isSubmitted) {
      print('[DQ] _submit early return - already submitted');
      return;
    }

    final controller = context.read<DailyQuestionController>();
    try {
      print('[DQ] Submitting answer to backend...');
      await controller.submitAnswer(_currentAnswer);
      if (mounted) {
        print(
            '[DQ] Answer submitted successfully, cancelling timer and updating state');
        _timer?.cancel();
        setState(() {
          _isSubmitted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Answer submitted! Results will be available soon.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[DQ] Error submitting answer: $e');
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

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final controller = context.watch<DailyQuestionController>();

    if (_isLoading) {
      return Scaffold(
        backgroundColor: appTheme.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // For past dates without a question, show results-only view
    if (_isPastDate && _question == null) {
      return _buildResultsOnlyView(appTheme);
    }

    // User submitted but returned without question loaded - show submitted view
    if (_submittedWithoutQuestion && _question == null) {
      return _buildSubmittedView(appTheme, controller);
    }

    // No question loaded and not a past date view
    if (_question == null) {
      return Scaffold(
        backgroundColor: appTheme.bg,
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
      );
    }

    final bool inputsEnabled = !_isSubmitted;
    final resultsStatus = _getResultsStatus();
    final showResultsSheet = _isSubmitted;

    return Scaffold(
      backgroundColor: appTheme.bg,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header with back button and timer
                _buildHeader(appTheme, inputsEnabled),

                // Question and input area
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Question-Answer Card
                          QuestionAnswerCard(
                            questionText: _question!.text,
                            tags: const [], // No tags for daily question
                            currentAnswer: _currentAnswer,
                            submittedAnswer: null,
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
                            buttonWidget: MainButton(
                              onPressed: inputsEnabled ? _submit : null,
                              label: MainButtonLabel.submit,
                              showSpacebarGlyph: false,
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
          ),

          // Results bottom sheet
          if (showResultsSheet)
            DQResultsBottomSheet(
              questionDate: _effectiveDate ?? '',
              status: resultsStatus,
              windowEnd: controller.todayDocument?.windowEnd,
              onResultsViewed: _onResultsViewed,
              service: context.read<DailyQuestionService>(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppTheme appTheme, bool showTimer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: Icon(Icons.arrow_back, color: appTheme.text),
            onPressed: () => Navigator.of(context).pop(),
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
          if (_isSubmitted && !_isPastDate)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: appTheme.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Submitted',
                style: AppFont.secondaryTextStyle(
                  context,
                  fontSize: 14,
                  color: appTheme.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          const Spacer(),

          // Placeholder for symmetry
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBackButton(AppTheme appTheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: appTheme.text),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Leave',
        ),
      ),
    );
  }

  /// Build a submitted view when user returns after submission (no question data).
  Widget _buildSubmittedView(
      AppTheme appTheme, DailyQuestionController controller) {
    final resultsStatus = _getResultsStatus();
    final effectiveDate = _effectiveDate ?? '';

    return Scaffold(
      backgroundColor: appTheme.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: appTheme.text),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Leave',
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: appTheme.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Submitted',
                          style: AppFont.secondaryTextStyle(
                            context,
                            fontSize: 14,
                            color: appTheme.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Submitted message
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
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
                          'Waiting for results...',
                          style: AppFont.secondaryTextStyle(
                            context,
                            color: appTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 120), // Space for bottom sheet
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Results bottom sheet
          DQResultsBottomSheet(
            questionDate: effectiveDate,
            status: resultsStatus,
            windowEnd: controller.todayDocument?.windowEnd,
            onResultsViewed: _onResultsViewed,
            service: context.read<DailyQuestionService>(),
          ),
        ],
      ),
    );
  }

  /// Build a results-only view for past dates.
  Widget _buildResultsOnlyView(AppTheme appTheme) {
    return Scaffold(
      backgroundColor: appTheme.bg,
      body: Stack(
        children: [
          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: appTheme.text),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Leave',
                  ),
                  const Spacer(),
                  Text(
                    'Results - ${widget.questionDate}',
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 16,
                      color: appTheme.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // Results sheet (expanded by default for past dates)
          DQResultsBottomSheet(
            questionDate: widget.questionDate ?? '',
            status: DQResultsHandleStatus.seen,
            onResultsViewed: _onResultsViewed,
            service: context.read<DailyQuestionService>(),
          ),
        ],
      ),
    );
  }
}
