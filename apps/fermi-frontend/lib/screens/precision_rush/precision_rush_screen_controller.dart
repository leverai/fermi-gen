import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/models/precision_rush_models.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/feedback_service.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';

/// Controller for the Precision Rush screen.
/// Manages timer, question state, answer submission, and run progression.
class PrecisionRushScreenController extends ChangeNotifier {
  final ApiService apiService;
  final String userLocale;
  final GameConfig? gameConfig;
  final bool initialWithAd;

  PrecisionRushScreenController({
    required this.apiService,
    required this.userLocale,
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
  PRQuestionData? _currentQuestion;
  PRQuestionData? get currentQuestion => _currentQuestion;

  int _questionNumber = 0;
  int get questionNumber => _questionNumber;

  int _totalQuestions = 6;
  int get totalQuestions => _totalQuestions;

  // Scoring
  double _totalTas = 0.0;
  double get totalTas => _totalTas;

  double _currentTas = 0.0;
  double get currentTas => _currentTas;

  bool _isFinal = false;
  bool get isFinal => _isFinal;

  PRRunSummary? _runSummary;
  PRRunSummary? get runSummary => _runSummary;

  // Answer state
  AnswerValue _userAnswer =
      const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
  AnswerValue get userAnswer => _userAnswer;

  bool _isSubmitted = false;
  bool get isSubmitted => _isSubmitted;

  PRAnswerResponse? _answerResponse;
  PRAnswerResponse? get answerResponse => _answerResponse;

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

  // Callback for showing PA card popup
  Future<void> Function()? onShowPACard;

  // --- Lifecycle ---

  /// Initialize the controller and start a new PR run.
  Future<void> attach() async {
    _currentLocale = userLocale;
    await _startRun(withAd: initialWithAd);
  }

  Future<void> _startRun({int? runId, bool withAd = false}) async {
    _isLoading = true;
    _error = null;
    _isSubmitted = false;
    _answerResponse = null;
    notifyListeners();

    try {
      final json = await apiService.prCreateOrResume(
        runId: runId,
        withAd: withAd,
      );
      final response = PRQuestionResponse.fromJson(json);

      _runId = response.runId;
      _questionNumber = response.questionNumber;
      _totalQuestions = response.totalQuestions;
      _currentQuestion = response.question;
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
      final json = await apiService.prSubmitAnswer(
        runId: _runId!,
        answer: answerToSubmit,
      );
      _answerResponse = PRAnswerResponse.fromJson(json);
      _isSubmitted = true;
      _isFinal = _answerResponse!.isFinal;
      _totalTas = _answerResponse!.totalTas;
      _currentTas = _answerResponse!.tas;
      if (_answerResponse!.runSummary != null) {
        _runSummary = _answerResponse!.runSummary;
      }

      FeedbackService.instance
          .playSuccess(); // Always success sound in PR (no fail)

      // Schedule PA card popup
      _schedulePostRevealPopups();

      // Hide unit tape indicators
      unitTapeController.setRevealed(true, const Duration(milliseconds: 600));

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Request next question.
  Future<void> requestNext() async {
    if (_isFinal || _runId == null) return;

    unitTapeController.setRevealed(false, Duration.zero);
    await _startRun(runId: _runId);
  }

  /// Submit current answer before leaving (for leave dialog flow).
  Future<void> submitBeforeLeave() async {
    if (!_isSubmitted) {
      await submitAnswer();
    }
  }

  /// Schedule PA card popup (if eligible) after reveal.
  void _schedulePostRevealPopups() {
    final percentile = _answerResponse?.percentile;
    final showPACard =
        percentile != null && (percentile <= 10 || percentile >= 90);

    if (showPACard && onShowPACard != null) {
      onShowPACard!();
    }
  }

  /// Get unit abbreviation from unit ID using the current question's unit map.
  String getUnitAbbreviationFromId(String unitId) {
    for (final entry in _unitAbbreviationToId.entries) {
      if (entry.value == unitId) {
        return entry.key;
      }
    }
    return unitId;
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
