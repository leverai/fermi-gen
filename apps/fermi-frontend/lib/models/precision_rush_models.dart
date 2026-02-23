/// Models for Precision Rush mode API responses.
library precision_rush_models;

import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/number_decompose.dart';

/// Question data returned for precision rush mode.
class PRQuestionData {
  final String questionUid;
  final String text;
  final String? category;
  final String? difficulty;
  final int? year;
  final Map<String, List<Map<String, String>>>? units;
  final int upvotes;
  final int userVote;

  const PRQuestionData({
    required this.questionUid,
    required this.text,
    this.category,
    this.difficulty,
    this.year,
    this.units,
    required this.upvotes,
    required this.userVote,
  });

  factory PRQuestionData.fromJson(Map<String, dynamic> json) {
    Map<String, List<Map<String, String>>>? parsedUnits;
    if (json['units'] != null) {
      parsedUnits = {};
      final unitsJson = json['units'] as Map<String, dynamic>;
      for (final entry in unitsJson.entries) {
        final localeUnits = (entry.value as List).map((u) {
          final unitMap = u as Map<String, dynamic>;
          return {
            'id': unitMap['id']?.toString() ?? '',
            'name': unitMap['name']?.toString() ?? '',
            'abbreviation': unitMap['abbreviation']?.toString() ?? '',
          };
        }).toList();
        parsedUnits[entry.key] = localeUnits;
      }
    }

    return PRQuestionData(
      questionUid: json['question_uid'] as String,
      text: json['text'] as String,
      category: json['category'] as String?,
      difficulty: json['difficulty'] as String?,
      year: json['year'] as int?,
      units: parsedUnits,
      upvotes: json['upvotes'] as int? ?? 0,
      userVote: json['user_vote'] as int? ?? 0,
    );
  }
}

/// Response for starting/resuming PR run.
class PRQuestionResponse {
  final int runId;
  final int questionNumber;
  final int totalQuestions;
  final PRQuestionData question;
  final double totalTas;
  final int timeLimitSeconds;
  final DateTime answerDeadlineUtc;

  const PRQuestionResponse({
    required this.runId,
    required this.questionNumber,
    required this.totalQuestions,
    required this.question,
    required this.totalTas,
    required this.timeLimitSeconds,
    required this.answerDeadlineUtc,
  });

  factory PRQuestionResponse.fromJson(Map<String, dynamic> json) {
    return PRQuestionResponse(
      runId: json['run_id'] as int,
      questionNumber: json['question_number'] as int,
      totalQuestions: json['total_questions'] as int,
      question:
          PRQuestionData.fromJson(json['question'] as Map<String, dynamic>),
      totalTas: (json['total_tas'] as num).toDouble(),
      timeLimitSeconds: json['time_limit_seconds'] as int,
      answerDeadlineUtc: DateTime.parse(json['answer_deadline_utc'] as String),
    );
  }
}

/// Summary of a completed PR run.
class PRRunSummary {
  final int runId;
  final int questionsAnswered;
  final double totalTas;

  const PRRunSummary({
    required this.runId,
    required this.questionsAnswered,
    required this.totalTas,
  });

  factory PRRunSummary.fromJson(Map<String, dynamic> json) {
    return PRRunSummary(
      runId: json['run_id'] as int,
      questionsAnswered: json['questions_answered'] as int,
      totalTas: (json['total_tas'] as num).toDouble(),
    );
  }
}

/// Response for PR answer submission.
class PRAnswerResponse {
  final double score;
  final double tas;
  final double percentile;
  final AnswerValue correctAnswer;
  final AnswerValue convertedCorrectAnswer;
  final AnswerValue userAnswer;
  final int questionNumber;
  final double totalTas;
  final bool isFinal;
  final PRRunSummary? runSummary;
  final String? aiOverview;

  const PRAnswerResponse({
    required this.score,
    required this.tas,
    required this.percentile,
    required this.correctAnswer,
    required this.convertedCorrectAnswer,
    required this.userAnswer,
    required this.questionNumber,
    required this.totalTas,
    required this.isFinal,
    this.runSummary,
    this.aiOverview,
  });

  factory PRAnswerResponse.fromJson(Map<String, dynamic> json) {
    return PRAnswerResponse(
      score: (json['score'] as num).toDouble(),
      tas: (json['tas'] as num).toDouble(),
      percentile: (json['percentile'] as num).toDouble(),
      correctAnswer: _parseAnswerValue(json['correct_answer']),
      convertedCorrectAnswer:
          _parseAnswerValue(json['converted_correct_answer']),
      userAnswer: _parseAnswerValue(json['user_answer']),
      questionNumber: json['question_number'] as int,
      totalTas: (json['total_tas'] as num).toDouble(),
      isFinal: json['is_final'] as bool,
      runSummary: json['run_summary'] != null
          ? PRRunSummary.fromJson(json['run_summary'] as Map<String, dynamic>)
          : null,
      aiOverview: json['ai_overview'] as String?,
    );
  }
}

/// Parse an answer value from JSON.
AnswerValue _parseAnswerValue(dynamic json) {
  if (json == null) {
    return const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
  }
  final map = json as Map<String, dynamic>;
  final numValue = map['number'] as num? ?? 1;
  final String unit = map['unit'] as String? ?? '';
  return decomposeNumber(numValue.toDouble(), unit);
}

/// User's PR statistics.
class PRStatsResponse {
  final int totalRuns;
  final double bestTas;
  final double averageTas;
  final int? activeRunId;
  final int? activeRunQuestionsAnswered;

  const PRStatsResponse({
    required this.totalRuns,
    required this.bestTas,
    required this.averageTas,
    this.activeRunId,
    this.activeRunQuestionsAnswered,
  });

  factory PRStatsResponse.fromJson(Map<String, dynamic> json) {
    return PRStatsResponse(
      totalRuns: json['total_runs'] as int,
      bestTas: (json['best_tas'] as num).toDouble(),
      averageTas: (json['average_tas'] as num).toDouble(),
      activeRunId: json['active_run_id'] as int?,
      activeRunQuestionsAnswered: json['active_run_questions_answered'] as int?,
    );
  }
}

/// A single entry on the PR leaderboard.
class PRLeaderboardEntry {
  final int rank;
  final String? displayName;
  final String? picture;
  final String? rankPicture;
  final double bestTas;

  const PRLeaderboardEntry({
    required this.rank,
    this.displayName,
    this.picture,
    this.rankPicture,
    required this.bestTas,
  });

  factory PRLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return PRLeaderboardEntry(
      rank: json['rank'] as int,
      displayName: json['display_name'] as String?,
      picture: json['picture'] as String?,
      rankPicture: json['rank_picture'] as String?,
      bestTas: (json['best_tas'] as num).toDouble(),
    );
  }
}

/// Paginated response for the PR leaderboard.
class PRLeaderboardResponse {
  final List<PRLeaderboardEntry> entries;
  final PRLeaderboardEntry? currentUser;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  const PRLeaderboardResponse({
    required this.entries,
    this.currentUser,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PRLeaderboardResponse.fromJson(Map<String, dynamic> json) {
    return PRLeaderboardResponse(
      entries: (json['entries'] as List)
          .map((e) => PRLeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentUser: json['current_user'] != null
          ? PRLeaderboardEntry.fromJson(
              json['current_user'] as Map<String, dynamic>)
          : null,
      totalCount: json['total_count'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      totalPages: json['total_pages'] as int,
    );
  }
}
