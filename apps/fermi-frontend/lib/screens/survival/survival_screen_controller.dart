import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/models/survival_models.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/ad_service.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';

/// Controller for the Survival screen.
/// Manages timer, question state, answer submission, and pass/fail flow.
/// No review mode - each question is one-shot.
class SurvivalScreenController extends ChangeNotifier {
  final ApiService apiService;
  final String userLocale;
  final int initialCurrentStreak;
  final int initialBestStreak;
  final GameConfig? gameConfig;
  final bool initialWithAd;

  SurvivalScreenController({
    required this.apiService,
    required this.userLocale,
    this.initialCurrentStreak = 0,
    this.initialBestStreak = 0,
    this.gameConfig,
    this.initialWithAd = false,
  });

  // --- State ---
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Current run
  int? _runId;
  int get runId => _runId ?? 0;

  // Question state
  SurvivalQuestionData? _currentQuestion;
  SurvivalQuestionData? get currentQuestion => _currentQuestion;

  int _questionNumber = 0;
  int get questionNumber => _questionNumber;

  // Streak tracking (initialized from constructor params)
  late int _currentStreak = initialCurrentStreak;
  int get currentStreak => _currentStreak;

  late int _bestStreak = initialBestStreak;
  int get bestStreak => _bestStreak;

  // Answer state
  AnswerValue _userAnswer =
      const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
  AnswerValue get userAnswer => _userAnswer;

  bool _isSubmitted = false;
  bool get isSubmitted => _isSubmitted;

  SurvivalAnswerResponse? _answerResponse;
  SurvivalAnswerResponse? get answerResponse => _answerResponse;

  bool get passed => _answerResponse?.passed ?? false;

  // Timer state
  Timer? _timer;
  DateTime? _deadline;
  Duration _timeLeft = Duration.zero;
  Duration get timeLeft => _timeLeft;

  double get timerProgress {
    if (_deadline == null) return 0.0;
    const totalDuration = Duration(seconds: 40);
    final elapsed = totalDuration - _timeLeft;
    return (elapsed.inMilliseconds / totalDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  // Unit state
  String _currentLocale = 'US';
  String get currentLocale => _currentLocale;

  List<String> _unitAbbreviations = [];
  List<String> get unitAbbreviations => _unitAbbreviations;

  Map<String, String> _unitOptions = {};
  Map<String, String> get unitOptions => _unitOptions;

  Map<String, String> _unitAbbreviationToId = {};

  final UnitTapeController unitTapeController = UnitTapeController();

  /// Get category display slug from backend name.
  String? getCategorySlug() {
    final name = _currentQuestion?.category;
    if (name == null || name.isEmpty) return null;
    final config = gameConfig;
    if (config == null) return name;
    final match = config.categories.where((c) => c.name == name).firstOrNull;
    return match?.slug ?? name;
  }

  /// Get difficulty display slug from backend name.
  String? getDifficultySlug() {
    final name = _currentQuestion?.difficulty;
    if (name == null || name.isEmpty) return null;
    final config = gameConfig;
    if (config == null) return name;
    final match = config.difficulties.where((d) => d.name == name).firstOrNull;
    return match?.slug ?? name;
  }

  /// Get year display string.
  String? getYearSlug() {
    final year = _currentQuestion?.year;
    if (year == null) return null;
    return year.toString();
  }

  // Confetti trigger
  bool _showConfetti = false;
  bool get showConfetti => _showConfetti;

  // Ad save state (from backend)
  bool _canUseAdSave = false; // Updated from backend responses
  bool get canUseAdSave => _canUseAdSave && AdService.instance.isAdLoaded;

  bool _isShowingAd = false;
  bool get isShowingAd => _isShowingAd;

  // Callback for showing save streak dialog (set by survival_screen)
  VoidCallback? onShowSaveDialog;

  // Callback for showing PA card popup (set by survival_screen)
  // Returns a Future that completes when the popup is closed
  Future<void> Function()? onShowPACard;

  // --- Lifecycle ---

  /// Initialize the controller and start a new survival run.
  Future<void> attach() async {
    _currentLocale = userLocale;
    // Streak values are passed from PreSurvivalScreen, no need to fetch
    await _startRun(withAd: initialWithAd);
  }

  Future<void> _startRun({int? runId, bool withAd = false}) async {
    _isLoading = true;
    _error = null;
    _isSubmitted = false;
    _answerResponse = null;
    _showConfetti = false;
    notifyListeners();

    try {
      final json = await apiService.survivalCreateOrResume(
        runId: runId,
        withAd: withAd,
      );
      final response = SurvivalQuestionResponse.fromJson(json);

      _runId = response.runId;
      _questionNumber = response.questionNumber;
      _currentQuestion = response.question;
      _currentStreak = response.streak;
      _canUseAdSave = response.canUseAdSave;
      _deadline = response.answerDeadlineUtc;

      // Initialize units
      _initializeUnits(response.question.units, _currentLocale);

      // Reset user answer with default unit
      if (_unitAbbreviations.isNotEmpty) {
        _userAnswer = AnswerValue(
          number: 1,
          orderOfMagnitude: '',
          unit: _unitAbbreviations.last,
        );
      } else {
        _userAnswer =
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
      }

      // Start timer
      _startTimer();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
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

    final localeUnits = units[locale.toUpperCase()] ?? units['US'] ?? [];

    if (localeUnits.isEmpty) {
      _unitAbbreviations = [];
      _unitOptions = {};
      _unitAbbreviationToId = {};
      return;
    }

    _unitAbbreviations = localeUnits
        .map((u) => u['abbreviation'] ?? '')
        .where((a) => a.isNotEmpty)
        .toList();

    _unitOptions = {
      for (final u in localeUnits)
        if (u['name'] != null && u['abbreviation'] != null)
          u['name']!: u['abbreviation']!
    };

    _unitAbbreviationToId = {
      for (final u in localeUnits)
        if (u['abbreviation'] != null && u['id'] != null)
          u['abbreviation']!: u['id']!
    };
  }

  // --- Timer ---

  void _startTimer() {
    _timer?.cancel();

    if (_deadline == null) return;

    _timeLeft = _deadline!.difference(DateTime.now().toUtc());
    if (_timeLeft.isNegative) {
      _timeLeft = Duration.zero;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _timeLeft = _deadline!.difference(DateTime.now().toUtc());
      if (_timeLeft.isNegative) {
        _timeLeft = Duration.zero;
      }

      if (_timeLeft.inSeconds <= 0 && !_isSubmitted) {
        _timer?.cancel();
        _autoSubmit();
      }

      notifyListeners();
    });
  }

  Future<void> _autoSubmit() async {
    await submitAnswer();
  }

  // --- Answer handling ---

  void onAnswerChanged(AnswerValue value) {
    if (_isSubmitted) return;
    _userAnswer = value;
    notifyListeners();
  }

  void onLocaleChanged(String locale) {
    if (_isSubmitted) return;
    _currentLocale = locale;
    _initializeUnits(_currentQuestion?.units, locale);

    // Persist locale
    apiService.setUserLocale(locale: locale);
    notifyListeners();
  }

  /// Submit the current answer.
  Future<void> submitAnswer() async {
    if (_isSubmitted || _runId == null) return;

    _timer?.cancel();

    // Convert unit abbreviation to ID
    final unitId = _userAnswer.unit.isNotEmpty
        ? (_unitAbbreviationToId[_userAnswer.unit] ?? _userAnswer.unit)
        : '';
    final answerToSubmit = _userAnswer.copyWith(unit: unitId);

    try {
      final json = await apiService.survivalSubmitAnswer(
        runId: _runId!,
        answer: answerToSubmit,
      );
      _answerResponse = SurvivalAnswerResponse.fromJson(json);
      _isSubmitted = true;

      // Update streak from runSummary.streak (backend's source of truth)
      // This correctly accounts for ad saves
      if (_answerResponse!.runSummary != null) {
        _currentStreak = _answerResponse!.runSummary!.streak;
      } else if (_answerResponse!.passed) {
        _currentStreak = _answerResponse!.totalQuestions;
      } else {
        _currentStreak = _answerResponse!.totalQuestions - 1;
      }

      // Update best streak if current is higher
      if (_currentStreak > _bestStreak) {
        _bestStreak = _currentStreak;
      }

      // Show confetti on pass
      if (_answerResponse!.passed) {
        _showConfetti = true;
      }

      // Schedule PA card popup and save streak dialog
      _schedulePostRevealPopups();

      // Hide unit tape indicators
      unitTapeController.setRevealed(true, const Duration(milliseconds: 600));

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Request next question (only valid if passed).
  Future<void> requestNext() async {
    if (!passed || _runId == null) return;

    _showConfetti = false;
    unitTapeController.setRevealed(false, Duration.zero);
    await _startRun(runId: _runId);
  }

  /// Clear confetti flag.
  void clearConfetti() {
    _showConfetti = false;
    notifyListeners();
  }

  /// Submit current answer before leaving (for leave dialog flow).
  Future<void> submitBeforeLeave() async {
    if (!_isSubmitted) {
      await submitAnswer();
    }
  }

  /// Schedule PA card popup (if eligible) and save streak dialog.
  /// PA card shows first, then save streak 1s after PA card closes.
  /// If no PA card, save streak shows 1s after reveal.
  void _schedulePostRevealPopups() {
    final percentile = _answerResponse?.percentile;
    final showPACard =
        percentile != null && (percentile <= 10 || percentile >= 90);

    if (showPACard && onShowPACard != null) {
      // Show PA card first, then schedule save streak after it closes
      onShowPACard!().then((_) {
        _scheduleSaveStreakIfNeeded();
      });
    } else {
      // No PA card to show, schedule save streak after 1s delay
      _scheduleSaveStreakIfNeeded();
    }
  }

  /// Schedule save streak dialog 1s after being called (if player failed).
  void _scheduleSaveStreakIfNeeded() {
    if (!passed && canUseAdSave) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!_isShowingAd) {
          onShowSaveDialog?.call();
        }
      });
    }
  }

  /// Get unit abbreviation from unit ID using the current question's unit map.
  String getUnitAbbreviationFromId(String unitId) {
    // Reverse lookup in _unitAbbreviationToId
    for (final entry in _unitAbbreviationToId.entries) {
      if (entry.value == unitId) {
        return entry.key;
      }
    }
    // Fallback: return the ID itself (might already be abbreviation)
    return unitId;
  }

  /// Continue the run after watching a rewarded ad.
  /// Shows the ad, then calls the API on completion.
  Future<void> continueWithAd({VoidCallback? onFailed}) async {
    if (!canUseAdSave || _runId == null || _isShowingAd) return;

    _isShowingAd = true;
    notifyListeners();

    final success = AdService.instance.showRewardedAd(
      onComplete: () async {
        _isShowingAd = false;
        // Call API to continue run
        try {
          final json = await apiService.survivalContinueWithAd(runId: _runId!);
          final response = SurvivalQuestionResponse.fromJson(json);

          // Reset state for the new question
          _runId = response.runId;
          _questionNumber = response.questionNumber;
          _currentQuestion = response.question;
          _deadline = response.answerDeadlineUtc;
          _isSubmitted = false;
          _answerResponse = null;
          _showConfetti = false;

          // Use backend values - streak preserved, ad saves now exhausted
          _currentStreak = response.streak;
          _canUseAdSave = response.canUseAdSave;

          // Reinitialize units
          _initializeUnits(response.question.units, _currentLocale);

          // Reset user answer
          if (_unitAbbreviations.isNotEmpty) {
            _userAnswer = AnswerValue(
              number: 1,
              orderOfMagnitude: '',
              unit: _unitAbbreviations.last,
            );
          } else {
            _userAnswer = const AnswerValue(
              number: 1,
              orderOfMagnitude: '',
              unit: '',
            );
          }

          // Restart timer
          _startTimer();
          unitTapeController.setRevealed(false, Duration.zero);

          notifyListeners();
        } catch (e) {
          _error = e.toString();
          _canUseAdSave = false;
          notifyListeners();
          onFailed?.call();
        }
      },
      onSkipped: () {
        _isShowingAd = false;
        notifyListeners();
        onFailed?.call();
      },
      onFailed: () {
        _isShowingAd = false;
        _canUseAdSave = false;
        notifyListeners();
        onFailed?.call();
      },
    );

    if (!success) {
      _isShowingAd = false;
      _canUseAdSave = false;
      notifyListeners();
      onFailed?.call();
    }
  }

  // --- Vote actions ---

  Future<void> onUpvote() async {
    final uid = _currentQuestion?.questionUid;
    if (uid == null) return;
    await apiService.upvoteQuestion(questionUid: uid);
  }

  Future<void> onDeUpvote() async {
    final uid = _currentQuestion?.questionUid;
    if (uid == null) return;
    await apiService.deUpvoteQuestion(questionUid: uid);
  }

  Future<void> onDownvote() async {
    final uid = _currentQuestion?.questionUid;
    if (uid == null) return;
    await apiService.downvoteQuestion(questionUid: uid);
  }

  Future<void> onDeDownvote() async {
    final uid = _currentQuestion?.questionUid;
    if (uid == null) return;
    await apiService.deDownvoteQuestion(questionUid: uid);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
