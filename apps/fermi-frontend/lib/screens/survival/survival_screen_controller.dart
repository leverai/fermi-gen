import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/models/survival_models.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';

/// Controller for the Survival screen.
/// Manages timer, question state, answer submission, and pass/fail flow.
/// No review mode - each question is one-shot.
class SurvivalScreenController extends ChangeNotifier {
  final ApiService apiService;
  final String userLocale;
  final int initialCurrentStreak;
  final int initialBestStreak;

  SurvivalScreenController({
    required this.apiService,
    required this.userLocale,
    this.initialCurrentStreak = 0,
    this.initialBestStreak = 0,
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

  // Confetti trigger
  bool _showConfetti = false;
  bool get showConfetti => _showConfetti;

  // --- Lifecycle ---

  /// Initialize the controller and start a new survival run.
  Future<void> attach() async {
    _currentLocale = userLocale;
    // Streak values are passed from PreSurvivalScreen, no need to fetch
    await _startRun();
  }

  Future<void> _startRun({int? runId}) async {
    _isLoading = true;
    _error = null;
    _isSubmitted = false;
    _answerResponse = null;
    _showConfetti = false;
    notifyListeners();

    try {
      final json = await apiService.survivalCreateOrResume(runId: runId);
      final response = SurvivalQuestionResponse.fromJson(json);

      _runId = response.runId;
      _questionNumber = response.questionNumber;
      _currentQuestion = response.question;
      _currentStreak = response.questionNumber - 1; // Started at 0
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
      _currentStreak = _answerResponse!.totalQuestions;

      // Update best streak if current is higher
      if (_currentStreak > _bestStreak) {
        _bestStreak = _currentStreak;
      }

      // Show confetti on pass
      if (_answerResponse!.passed) {
        _showConfetti = true;
      }

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
