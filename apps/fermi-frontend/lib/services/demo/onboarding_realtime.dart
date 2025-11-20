import 'dart:async';
import 'dart:math' as math;

import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/utils/om_constants.dart';
import 'package:fermi_frontend/models/answer_value.dart';

/// In-memory realtime adapter for onboarding flow.
///
/// Provides a single question with local scoring, no backend calls.
class OnboardingRealtime implements GameRealtime {
  OnboardingRealtime({String initialLocale = 'US'}) : _locale = initialLocale;

  String _locale;

  @override
  String get currentPlayerId => 'me';

  @override
  String? get currentLocale => _locale;

  final _game = StreamController<GameSnapshot>.broadcast();
  final _q = StreamController<RevealedQuestion>.broadcast();
  final _players = StreamController<PlayersAnswersSnapshot>.broadcast();
  final _reveal = StreamController<RevealPayload>.broadcast();

  // Store the latest question so we can emit it to late subscribers.
  // Broadcast streams don't replay values, so we need to manually emit
  // when the stream is accessed to ensure subscribers receive the question.
  RevealedQuestion? _latestQuestion;

  @override
  Stream<GameSnapshot> watchGame(String gameId) {
    // Use a fixed question UID for onboarding
    const String questionUid = 'onboarding-question-1';

    // Emit GameSnapshot first
    Future.microtask(() {
      _game.add(const GameSnapshot(
        state: GameState.questionN,
        isHost: true,
        questionNumber: 1,
        nQuestions: 1,
        durationSeconds: 0, // No timer in onboarding
        players: {
          'me': PlayerSummary(
            playerId: 'me',
            name: 'You',
            pictureUrl: null,
            score: 0,
            isHost: false,
            isActive: true,
            rank: 1,
          ),
        },
        isPrivate: false,
        currentQuestionUid: questionUid,
        questionUids: [questionUid],
      ));
    });

    // Build and store the question
    _latestQuestion = _buildRevealedQuestion();

    // Emit question after a small delay to ensure listener is set up
    Future.microtask(() {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_latestQuestion != null && !_q.isClosed) {
          _q.add(_latestQuestion!);
        }
      });
    });

    return _game.stream;
  }

  RevealedQuestion _buildRevealedQuestion() {
    // Return units for the current locale
    final List<String> units;
    final Map<String, String> unitOptions;
    final Map<String, String> abbrToId;
    final Map<String, String> idToAbbr;

    if (_locale == 'EU') {
      units = ['km'];
      unitOptions = {'Kilometer': 'km'};
      abbrToId = {'km': 'kilometer'};
      idToAbbr = {'kilometer': 'km'};
    } else {
      units = ['mi'];
      unitOptions = {'Mile': 'mi'};
      abbrToId = {'mi': 'mile'};
      idToAbbr = {'mile': 'mi'};
    }

    return RevealedQuestion(
      text: 'How tall would a billion dollars stack be? Assume \$1 bills.',
      tags: const ['Shower Thoughts', 'Pro', '2025'],
      units: units,
      unitOptions: unitOptions,
      unitAbbreviationToId: abbrToId,
      unitIdToAbbreviation: idToAbbr,
      upvotes: 999,
      myVoteVerdict: 0,
      category: 'SHOWER_THOUGHTS',
    );
  }

  @override
  Stream<RevealedQuestion> revealedQuestion(String gid, int i) {
    // Ensure question is built if not already
    _latestQuestion ??= _buildRevealedQuestion();

    // Emit immediately to any current subscribers, and also set up the stream
    // This ensures late subscribers get the question
    Future.microtask(() {
      if (_latestQuestion != null && !_q.isClosed) {
        _q.add(_latestQuestion!);
      }
    });

    return _q.stream;
  }

  @override
  Stream<PlayersAnswersSnapshot> playersAnswersForQuestion(String gid, int i) =>
      _players.stream;

  @override
  Stream<RevealPayload> revealsForQuestion(String gid, int i) => _reveal.stream;

  @override
  Future<void> submitAnswer(String gid, int i, AnswerValue answer) async {
    // Compute score immediately to avoid red flash
    final _Truth truth = _truthFor(_locale);
    final double score = _computeScore(answer, truth);

    // Correct answer in absolute terms (for backend format)
    final AnswerValue correctAbsolute = AnswerValue(
      number: truth.absolute,
      orderOfMagnitude: '',
      unit: truth.backendUnitId,
    );

    // Correct answer in display format (for UI reveal)
    final AnswerValue correctDisplay = AnswerValue(
      number: truth.displayNumber,
      orderOfMagnitude: truth.displayOm,
      unit: truth.displayAbbr,
    );

    // Immediately emit submitted answer with computed score and correct answer
    // This avoids double-counting the score (controller accumulates scores)
    _players.add(PlayersAnswersSnapshot(
      submitted: {'me': answer},
      scores: {'me': score},
      correct: {'me': correctAbsolute},
      allAnswered: true,
    ));

    // Wait 400ms before revealing the correct answer visually
    await Future.delayed(const Duration(milliseconds: 400));

    // Emit reveal payload to show the correct answer
    _reveal.add(RevealPayload(correct: correctDisplay));
  }

  @override
  Future<void> requestForceReveal(String gid, int i) async {
    // No-op for onboarding
  }

  @override
  Future<void> goNext(String gid) async {
    // No-op for onboarding (single question)
  }

  @override
  Future<void> setUserLocale(String loc) async {
    _locale = loc;
    _latestQuestion = _buildRevealedQuestion();
    if (!_q.isClosed) {
      _q.add(_latestQuestion!);
    }
  }

  @override
  Future<void> upvoteQuestion(String questionUid) async {
    // No-op for onboarding
  }

  @override
  Future<void> deUpvoteQuestion(String questionUid) async {
    // No-op for onboarding
  }

  @override
  Future<void> downvoteQuestion(String questionUid) async {
    // No-op for onboarding
  }

  @override
  Future<void> deDownvoteQuestion(String questionUid) async {
    // No-op for onboarding
  }

  // ========== Helper methods ==========

  /// Convert (number, orderOfMagnitude) to absolute value.
  /// E.g., (68, '') -> 68, (5, 'K') -> 5000
  double _toAbsoluteValue(int number, String om) {
    final int magnitude = orderOfMagnitudePowers[om] ?? 0;
    return number * math.pow(10, magnitude).toDouble();
  }

  /// Convert a value from one unit to another.
  /// Only supports miles <-> kilometers for this onboarding question.
  double _convertUnit(double value, String fromUnit, String toUnit) {
    const milesToKm = 1.60934;

    if (fromUnit == toUnit) return value;

    // Normalize unit names
    final from = _normalizeUnit(fromUnit);
    final to = _normalizeUnit(toUnit);

    if (from == to) return value;

    if (from == 'mile' && to == 'kilometer') {
      return value * milesToKm;
    } else if (from == 'kilometer' && to == 'mile') {
      return value / milesToKm;
    }

    // Unknown conversion, return as-is
    return value;
  }

  String _normalizeUnit(String unit) {
    switch (unit.toLowerCase()) {
      case 'mi':
      case 'mile':
        return 'mile';
      case 'km':
      case 'kilometer':
        return 'kilometer';
      default:
        return unit.toLowerCase();
    }
  }

  /// Compute score based on player's answer and truth.
  double _computeScore(AnswerValue answer, _Truth truth) {
    final double playerAbsolute =
        _toAbsoluteValue(answer.number, answer.orderOfMagnitude);

    // Convert player's answer to truth's unit for comparison
    final double playerInTruthUnit = _convertUnit(
      playerAbsolute,
      answer.unit,
      truth.backendUnitId,
    );

    if (playerInTruthUnit <= 0) return 0.0;

    // ratio = max(player / truth, truth / player)
    final double ratio = playerInTruthUnit / truth.value;
    final double r = ratio >= 1.0 ? ratio : 1.0 / ratio;

    // score = 6000 / sqrt(ratio)
    final double score = 6000.0 / math.sqrt(r);
    return score.clamp(0.0, 6000.0);
  }

  /// Get truth data for the given locale.
  _Truth _truthFor(String locale) {
    if (locale == 'EU') {
      // EU: 109 km
      return const _Truth(
        value: 109.0,
        backendUnitId: 'kilometer',
        displayNumber: 109,
        displayOm: '',
        displayAbbr: 'km',
        absolute: 109,
      );
    } else {
      // US: 68 miles
      return const _Truth(
        value: 68.0,
        backendUnitId: 'mile',
        displayNumber: 68,
        displayOm: '',
        displayAbbr: 'mi',
        absolute: 68,
      );
    }
  }
}

/// Internal struct to hold truth data.
class _Truth {
  final double value; // absolute value in base unit
  final String
      backendUnitId; // backend unit identifier (e.g., 'mile', 'kilometer')
  final int displayNumber; // number to display (1-999)
  final String displayOm; // order of magnitude to display ('', 'K', 'M', etc.)
  final String displayAbbr; // unit abbreviation to display ('mi', 'km')
  final int absolute; // absolute number for backend format

  const _Truth({
    required this.value,
    required this.backendUnitId,
    required this.displayNumber,
    required this.displayOm,
    required this.displayAbbr,
    required this.absolute,
  });
}
