import 'dart:convert';

import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/number_decompose.dart'; // composeNumber, decomposeNumber
import 'package:http/http.dart' as http;

/// Lite archive response from /archive/week and /archive/month.
/// Contains participation data and the current "today" date.
class DQLiteArchiveResponse {
  final Map<String, bool> items; // {date (YYYY-MM-DD): user_participated}
  final String today; // Current DQ date for Firestore subscription

  DQLiteArchiveResponse({
    required this.items,
    required this.today,
  });

  factory DQLiteArchiveResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as Map<String, dynamic>;
    final items = rawItems.map((k, v) => MapEntry(k, v as bool));
    return DQLiteArchiveResponse(
      items: items,
      today: json['today'] as String,
    );
  }
}

/// Question response when starting a DQ.
class DQQuestionResponse {
  final String questionUid;
  final String text;
  final String category;
  final String difficulty;
  final Map<String, List<Map<String, String>>>? units; // {US: [...], EU: [...]}
  final DateTime answerDeadline;
  final double secondsToAnswer;

  DQQuestionResponse({
    required this.questionUid,
    required this.text,
    required this.category,
    required this.difficulty,
    this.units,
    required this.answerDeadline,
    required this.secondsToAnswer,
  });

  factory DQQuestionResponse.fromJson(Map<String, dynamic> json) {
    final questionData = json['question'] as Map<String, dynamic>;

    // Parse units from question data
    Map<String, List<Map<String, String>>>? units;
    if (questionData['units'] != null) {
      final rawUnits = questionData['units'] as Map<String, dynamic>;
      units = rawUnits.map((locale, unitList) => MapEntry(
            locale,
            (unitList as List)
                .map((u) => Map<String, String>.from(u as Map))
                .toList(),
          ));
    }

    return DQQuestionResponse(
      questionUid: questionData['question_uid'] as String,
      text: questionData['text'] as String,
      category: questionData['category'] as String? ?? '',
      difficulty: questionData['difficulty'] as String? ?? '',
      units: units,
      answerDeadline:
          DateTime.parse(json['answer_deadline_utc'] as String).toUtc(),
      secondsToAnswer: (json['seconds_to_answer'] as num).toDouble(),
    );
  }
}

/// Submit response from /answer endpoint.
class DQSubmitResponse {
  final bool submitted;
  final double? score;
  final String? message;

  DQSubmitResponse({
    required this.submitted,
    this.score,
    this.message,
  });

  factory DQSubmitResponse.fromJson(Map<String, dynamic> json) {
    return DQSubmitResponse(
      submitted: json['submitted'] as bool,
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      message: json['message'] as String?,
    );
  }
}

class DQResultsResponse {
  final String questionDate;
  final String questionUid;
  final String questionText;
  final AnswerValue correctAnswer;
  final AnswerValue? userAnswer;
  final double? userScore;
  final int? userRank;
  final bool userIsPostTake;
  final int totalParticipants;
  final List<DQLeaderboardEntry> leaderboard;
  final String? paragraph;

  DQResultsResponse({
    required this.questionDate,
    required this.questionUid,
    required this.questionText,
    required this.correctAnswer,
    this.userAnswer,
    this.userScore,
    this.userRank,
    this.userIsPostTake = false,
    required this.totalParticipants,
    required this.leaderboard,
    this.paragraph,
  });

  factory DQResultsResponse.fromJson(Map<String, dynamic> json) {
    // Parse correct answer - unit is now a UnitInfo object {id, name, abbreviation}
    final correctAnswerJson = json['correct_answer'] as Map<String, dynamic>;
    final correctAnswerNumber = (correctAnswerJson['number'] as num).toDouble();
    String correctAnswerUnit = '';
    if (correctAnswerJson['unit'] != null) {
      final unitInfo = correctAnswerJson['unit'] as Map<String, dynamic>;
      correctAnswerUnit = (unitInfo['abbreviation'] as String?) ?? '';
    }
    final correctAnswer =
        decomposeNumber(correctAnswerNumber, correctAnswerUnit);

    // Parse user answer (nullable) - unit is now a UnitInfo object
    AnswerValue? userAnswer;
    if (json['user_answer'] != null) {
      final userAnswerJson = json['user_answer'] as Map<String, dynamic>;
      final userAnswerNumber = (userAnswerJson['number'] as num).toDouble();
      String userAnswerUnit = '';
      if (userAnswerJson['unit'] != null) {
        final unitInfo = userAnswerJson['unit'] as Map<String, dynamic>;
        userAnswerUnit = (unitInfo['abbreviation'] as String?) ?? '';
      }
      userAnswer = decomposeNumber(userAnswerNumber, userAnswerUnit);
    }

    // Parse leaderboard
    final leaderboardJson = json['leaderboard'] as List? ?? [];
    final leaderboard = leaderboardJson
        .map((e) => DQLeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    return DQResultsResponse(
      questionDate: json['question_date'] as String,
      questionUid: json['question_uid'] as String,
      questionText: json['question_text'] as String,
      correctAnswer: correctAnswer,
      userAnswer: userAnswer,
      userScore: json['user_score'] != null
          ? (json['user_score'] as num).toDouble()
          : null,
      userRank: json['user_rank'] as int?,
      userIsPostTake: json['user_is_post_take'] as bool? ?? false,
      totalParticipants: json['total_participants'] as int,
      leaderboard: leaderboard,
      paragraph: json['paragraph'] as String?,
    );
  }
}

class DQPlayer {
  final String? displayName;
  final String? avatarUrl;

  DQPlayer({
    this.displayName,
    this.avatarUrl,
  });

  factory DQPlayer.fromJson(Map<String, dynamic> json) {
    return DQPlayer(
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class DQLeaderboardEntry {
  final int rank;
  final DQPlayer? player;
  final double score;
  final double timeTakenS;
  final bool isPostTake;
  final bool isCurrentUser;

  DQLeaderboardEntry({
    required this.rank,
    this.player,
    required this.score,
    required this.timeTakenS,
    this.isPostTake = false,
    this.isCurrentUser = false,
  });

  factory DQLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return DQLeaderboardEntry(
      rank: json['rank'] as int,
      player: json['player'] != null
          ? DQPlayer.fromJson(json['player'] as Map<String, dynamic>)
          : null,
      score: (json['score'] as num).toDouble(),
      timeTakenS: (json['time_taken_s'] as num).toDouble(),
      isPostTake: json['is_post_take'] as bool? ?? false,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }
}

/// Response from POST /post_take/{date}/answer with immediate results.
class DQPostTakeResultsResponse {
  final bool submitted;
  final double score;
  final int rank;
  final int totalParticipants;
  final String questionDate;
  final String questionText;
  final AnswerValue correctAnswer;
  final AnswerValue userAnswer;
  final List<DQLeaderboardEntry> leaderboard;
  final String? paragraph;

  DQPostTakeResultsResponse({
    required this.submitted,
    required this.score,
    required this.rank,
    required this.totalParticipants,
    required this.questionDate,
    required this.questionText,
    required this.correctAnswer,
    required this.userAnswer,
    required this.leaderboard,
    this.paragraph,
  });

  factory DQPostTakeResultsResponse.fromJson(Map<String, dynamic> json) {
    // Parse correct answer
    final correctAnswerJson = json['correct_answer'] as Map<String, dynamic>;
    final correctAnswerNumber = (correctAnswerJson['number'] as num).toDouble();
    String correctAnswerUnit = '';
    if (correctAnswerJson['unit'] != null) {
      final unitInfo = correctAnswerJson['unit'] as Map<String, dynamic>;
      correctAnswerUnit = (unitInfo['abbreviation'] as String?) ?? '';
    }
    final correctAnswer =
        decomposeNumber(correctAnswerNumber, correctAnswerUnit);

    // Parse user answer
    final userAnswerJson = json['user_answer'] as Map<String, dynamic>;
    final userAnswerNumber = (userAnswerJson['number'] as num).toDouble();
    String userAnswerUnit = '';
    if (userAnswerJson['unit'] != null) {
      final unitInfo = userAnswerJson['unit'] as Map<String, dynamic>;
      userAnswerUnit = (unitInfo['abbreviation'] as String?) ?? '';
    }
    final userAnswer = decomposeNumber(userAnswerNumber, userAnswerUnit);

    // Parse leaderboard
    final leaderboardJson = json['leaderboard'] as List? ?? [];
    final leaderboard = leaderboardJson
        .map((e) => DQLeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    return DQPostTakeResultsResponse(
      submitted: json['submitted'] as bool,
      score: (json['score'] as num).toDouble(),
      rank: json['rank'] as int,
      totalParticipants: json['total_participants'] as int,
      questionDate: json['question_date'] as String,
      questionText: json['question_text'] as String,
      correctAnswer: correctAnswer,
      userAnswer: userAnswer,
      leaderboard: leaderboard,
      paragraph: json['paragraph'] as String?,
    );
  }

  /// Convert to DQResultsResponse for use in existing result display code.
  DQResultsResponse toDQResultsResponse() {
    return DQResultsResponse(
      questionDate: questionDate,
      questionUid: '', // Not included in post-take response
      questionText: questionText,
      correctAnswer: correctAnswer,
      userAnswer: userAnswer,
      userScore: score,
      userRank: rank,
      userIsPostTake: true, // Post-take results are always from a post-take
      totalParticipants: totalParticipants,
      leaderboard: leaderboard,
      paragraph: paragraph,
    );
  }
}

class DailyQuestionService {
  final ApiService _api;

  DailyQuestionService({required ApiService api}) : _api = api;

  /// Helper to extract error message from error response body.
  String _extractErrorMessage(http.Response response) {
    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final dynamic detail = body['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        return body.toString();
      }
      return body?.toString() ?? 'HTTP ${response.statusCode}';
    } catch (_) {
      final String text = response.body;
      if (text.isNotEmpty) {
        return text.substring(0, text.length.clamp(0, 200));
      }
      return 'HTTP ${response.statusCode}';
    }
  }

  /// Helper to decode JSON from a successful (200) response, or throw on error.
  Map<String, dynamic> _decodeOkJson(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response));
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Invalid JSON response: $e');
    }
  }

  /// Get lite archive for DQ carousel (past 7 days + today).
  Future<DQLiteArchiveResponse> getWeeklyArchive() async {
    // print('[DQService] Calling getWeeklyArchive...');
    final response = await _api.get('/daily_question/archive/week');
    // print(
    //     '[DQService] Weekly archive response: ${response.statusCode} - ${response.body}');
    final data = _decodeOkJson(response);
    return DQLiteArchiveResponse.fromJson(data);
  }

  /// Get lite archive for a specific month (calendar view).
  Future<DQLiteArchiveResponse> getMonthlyArchive(int year, int month) async {
    // print('[DQService] Calling getMonthlyArchive($year, $month)...');
    final response = await _api.get(
      '/daily_question/archive/month?year=$year&month=$month',
    );
    // print(
    //     '[DQService] Monthly archive response: ${response.statusCode} - ${response.body}');
    final data = _decodeOkJson(response);
    return DQLiteArchiveResponse.fromJson(data);
  }

  /// Start today's daily question.
  Future<DQQuestionResponse> startQuestion() async {
    // print('[DQService] Calling startQuestion...');
    final response = await _api.post('/daily_question/start', {});
    final data = _decodeOkJson(response);
    return DQQuestionResponse.fromJson(data);
  }

  /// Submit an answer for the daily question.
  Future<DQSubmitResponse> submitAnswer(AnswerValue answer) async {
    // print('[DQService] Calling submitAnswer...');
    // Compose the number back from (number, orderOfMagnitude) to absolute value
    final absoluteNumber = composeNumber(answer);
    final response = await _api.post('/daily_question/answer', {
      'answer': {
        'number': absoluteNumber,
        'unit': answer.unit,
      }
    });
    final data = _decodeOkJson(response);
    return DQSubmitResponse.fromJson(data);
  }

  /// Get results for today's daily question.
  Future<DQResultsResponse> getResults() async {
    // print('[DQService] Calling getResults...');
    final response = await _api.get('/daily_question/results');
    final data = _decodeOkJson(response);
    return DQResultsResponse.fromJson(data);
  }

  /// Get results for a specific past daily question by date.
  Future<DQResultsResponse> getResultsForDate(
    String questionDate, {
    bool includePostTakes = true,
  }) async {
    final queryParam = includePostTakes ? '' : '?include_post_takes=false';
    final response =
        await _api.get('/daily_question/results/$questionDate$queryParam');
    final data = _decodeOkJson(response);
    return DQResultsResponse.fromJson(data);
  }

  /// Start a post-take for a closed daily question.
  ///
  /// If [withAd] is true, bypasses Pro subscription requirement (for ad-based access).
  Future<DQQuestionResponse> startPostTake(
    String questionDate, {
    bool withAd = false,
  }) async {
    final suffix = withAd ? '?with_ad=true' : '';
    final response = await _api.post(
      '/daily_question/post_take/$questionDate/start$suffix',
      {},
    );
    final data = _decodeOkJson(response);
    return DQQuestionResponse.fromJson(data);
  }

  /// Submit an answer for a post-take and get immediate results.
  ///
  /// If [withAd] is true, bypasses Pro subscription requirement (for ad-based access).
  Future<DQPostTakeResultsResponse> submitPostTakeAnswer(
    String questionDate,
    AnswerValue answer,
    DateTime startedAt, {
    bool withAd = false,
  }) async {
    final absoluteNumber = composeNumber(answer);
    final suffix = withAd ? '?with_ad=true' : '';
    final response = await _api.post(
      '/daily_question/post_take/$questionDate/answer$suffix',
      {
        'answer': {
          'number': absoluteNumber,
          'unit': answer.unit,
        },
        'started_at': startedAt.toUtc().toIso8601String(),
      },
    );
    final data = _decodeOkJson(response);
    return DQPostTakeResultsResponse.fromJson(data);
  }
}
