import 'dart:convert';

import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/number_decompose.dart';
import 'package:http/http.dart' as http;

/// Status response from the API.
class DQStatusResponse {
  final String windowStatus; // NOT_STARTED, ACTIVE, CLOSED
  final double? secondsUntilWindowEnd;
  final String? questionDate; // YYYY-MM-DD
  final String? userStatus; // NOT_STARTED, IN_PROGRESS, SUBMITTED, MISSED
  final bool hasResults;

  DQStatusResponse({
    required this.windowStatus,
    this.secondsUntilWindowEnd,
    this.questionDate,
    this.userStatus,
    required this.hasResults,
  });

  factory DQStatusResponse.fromJson(Map<String, dynamic> json) {
    return DQStatusResponse(
      windowStatus: json['window_status'] as String,
      secondsUntilWindowEnd: json['seconds_until_window_end'] != null
          ? (json['seconds_until_window_end'] as num).toDouble()
          : null,
      questionDate: json['question_date'] as String?,
      userStatus: json['user_status'] as String?,
      hasResults: json['has_results'] as bool? ?? false,
    );
  }

  /// Convenience getter: returns 'ACTIVE' equivalent for display purposes
  String get status => windowStatus;
}

/// Question response when starting a DQ.
class DQQuestionResponse {
  final String questionUid;
  final String text;
  final String category;
  final String difficulty;
  final DateTime answerDeadline;
  // Add other fields if needed from QuestionDoc

  DQQuestionResponse({
    required this.questionUid,
    required this.text,
    required this.category,
    required this.difficulty,
    required this.answerDeadline,
  });

  factory DQQuestionResponse.fromJson(Map<String, dynamic> json) {
    // Backend returns nested structure: { question: { question_uid, text, ... }, answer_deadline_utc, ... }
    final questionData = json['question'] as Map<String, dynamic>;
    return DQQuestionResponse(
      questionUid: questionData['question_uid'] as String,
      text: questionData['text'] as String,
      category: questionData['category'] as String? ?? '',
      difficulty: questionData['difficulty'] as String? ?? '',
      answerDeadline:
          DateTime.parse(json['answer_deadline_utc'] as String).toLocal(),
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
  final int totalParticipants;
  final List<DQLeaderboardEntry> leaderboard;

  DQResultsResponse({
    required this.questionDate,
    required this.questionUid,
    required this.questionText,
    required this.correctAnswer,
    this.userAnswer,
    this.userScore,
    this.userRank,
    required this.totalParticipants,
    required this.leaderboard,
  });

  factory DQResultsResponse.fromJson(Map<String, dynamic> json) {
    // Parse correct answer
    final correctAnswerJson = json['correct_answer'] as Map<String, dynamic>;
    final correctAnswerNumber = (correctAnswerJson['number'] as num).toDouble();
    final correctAnswerUnit = (correctAnswerJson['unit'] as String?) ?? '';
    final correctAnswer =
        decomposeNumber(correctAnswerNumber, correctAnswerUnit);

    // Parse user answer (nullable)
    AnswerValue? userAnswer;
    if (json['user_answer'] != null) {
      final userAnswerJson = json['user_answer'] as Map<String, dynamic>;
      final userAnswerNumber = (userAnswerJson['number'] as num).toDouble();
      final userAnswerUnit = (userAnswerJson['unit'] as String?) ?? '';
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
      totalParticipants: json['total_participants'] as int,
      leaderboard: leaderboard,
    );
  }
}

class DQLeaderboardEntry {
  final int rank;
  final String? displayName;
  final double score;
  final double timeTakenS;

  DQLeaderboardEntry({
    required this.rank,
    this.displayName,
    required this.score,
    required this.timeTakenS,
  });

  factory DQLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return DQLeaderboardEntry(
      rank: json['rank'] as int,
      displayName: json['display_name'] as String?,
      score: (json['score'] as num).toDouble(),
      timeTakenS: (json['time_taken_s'] as num).toDouble(),
    );
  }
}

class DQHistoryItem {
  final String questionDate; // YYYY-MM-DD
  final String questionText;
  final AnswerValue userAnswer;
  final AnswerValue correctAnswer;
  final double score;
  final int? rank;
  final int totalParticipants;

  DQHistoryItem({
    required this.questionDate,
    required this.questionText,
    required this.userAnswer,
    required this.correctAnswer,
    required this.score,
    this.rank,
    required this.totalParticipants,
  });

  factory DQHistoryItem.fromJson(Map<String, dynamic> json) {
    // Parse user answer
    final userAnswerJson = json['user_answer'] as Map<String, dynamic>;
    final userAnswerNumber = (userAnswerJson['number'] as num).toDouble();
    final userAnswerUnit = (userAnswerJson['unit'] as String?) ?? '';
    final userAnswer = decomposeNumber(userAnswerNumber, userAnswerUnit);

    // Parse correct answer
    final correctAnswerJson = json['correct_answer'] as Map<String, dynamic>;
    final correctAnswerNumber = (correctAnswerJson['number'] as num).toDouble();
    final correctAnswerUnit = (correctAnswerJson['unit'] as String?) ?? '';
    final correctAnswer =
        decomposeNumber(correctAnswerNumber, correctAnswerUnit);

    return DQHistoryItem(
      questionDate: json['question_date'] as String,
      questionText: json['question_text'] as String,
      userAnswer: userAnswer,
      correctAnswer: correctAnswer,
      score: (json['score'] as num).toDouble(),
      rank: json['rank'] as int?,
      totalParticipants: json['total_participants'] as int,
    );
  }
}

class DQArchiveItem {
  final String questionDate; // YYYY-MM-DD
  final String questionText;
  final int totalParticipants;
  final bool userParticipated;
  final double? userScore;
  final int? userRank;

  DQArchiveItem({
    required this.questionDate,
    required this.questionText,
    required this.totalParticipants,
    required this.userParticipated,
    this.userScore,
    this.userRank,
  });

  factory DQArchiveItem.fromJson(Map<String, dynamic> json) {
    return DQArchiveItem(
      questionDate: json['question_date'] as String,
      questionText: json['question_text'] as String,
      totalParticipants: json['total_participants'] as int,
      userParticipated: json['user_participated'] as bool,
      userScore: json['user_score'] != null
          ? (json['user_score'] as num).toDouble()
          : null,
      userRank: json['user_rank'] as int?,
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

  Future<DQStatusResponse> getStatus() async {
    print('[DQService] Calling getStatus...');
    final response = await _api.get('/daily_question/status');
    print(
        '[DQService] Status response: ${response.statusCode} - ${response.body}');
    final data = _decodeOkJson(response);
    return DQStatusResponse.fromJson(data);
  }

  Future<DQQuestionResponse> startQuestion() async {
    final response = await _api.post('/daily_question/start', {});
    final data = _decodeOkJson(response);
    return DQQuestionResponse.fromJson(data);
  }

  Future<void> submitAnswer(AnswerValue answer) async {
    final response = await _api.post('/daily_question/answer', {
      'answer': {
        'number': answer.number,
        'unit': answer.unit,
      }
    });
    // Check status code - backend returns 200 on success
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response));
    }
  }

  Future<DQResultsResponse> getResults() async {
    final response = await _api.get('/daily_question/results');
    final data = _decodeOkJson(response);
    return DQResultsResponse.fromJson(data);
  }

  /// Get results for a specific past daily question by date.
  Future<DQResultsResponse> getResultsForDate(String questionDate) async {
    print('[DQService] Calling getResultsForDate for $questionDate...');
    final response = await _api.get('/daily_question/results/$questionDate');
    print(
        '[DQService] Results response: ${response.statusCode} - ${response.body}');
    final data = _decodeOkJson(response);
    return DQResultsResponse.fromJson(data);
  }

  Future<List<DQHistoryItem>> getHistory() async {
    final response = await _api.get('/daily_question/history');
    final data = _decodeOkJson(response);
    final list = data['history'] as List;
    return list.map((e) => DQHistoryItem.fromJson(e)).toList();
  }

  Future<List<DQArchiveItem>> getArchive() async {
    print('[DQService] Calling getArchive...');
    final response = await _api.get('/daily_question/archive');
    print(
        '[DQService] Archive response: ${response.statusCode} - ${response.body}');
    final data = _decodeOkJson(response);
    final list = data['items'] as List;
    return list.map((e) => DQArchiveItem.fromJson(e)).toList();
  }
}
