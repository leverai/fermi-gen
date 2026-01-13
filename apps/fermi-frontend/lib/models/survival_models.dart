/// Models for Survival mode API responses.
library survival_models;

import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/number_decompose.dart';

/// Question data returned for survival mode.
class SurvivalQuestionData {
  final String questionUid;
  final String text;
  final String? category;
  final String? difficulty;
  final Map<String, List<Map<String, String>>>? units;
  final int upvotes;
  final int userVote; // -1=downvote, 0=neutral, 1=upvote (VoteVerdict IntEnum)

  const SurvivalQuestionData({
    required this.questionUid,
    required this.text,
    this.category,
    this.difficulty,
    this.units,
    required this.upvotes,
    required this.userVote,
  });

  factory SurvivalQuestionData.fromJson(Map<String, dynamic> json) {
    // Parse units map: {"US": [{"id": ..., "name": ..., "abbreviation": ...}], ...}
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

    return SurvivalQuestionData(
      questionUid: json['question_uid'] as String,
      text: json['text'] as String,
      category: json['category'] as String?,
      difficulty: json['difficulty'] as String?,
      units: parsedUnits,
      upvotes: json['upvotes'] as int? ?? 0,
      userVote: json['user_vote'] as int? ?? 0,
    );
  }
}

/// Response for starting/resuming survival run.
class SurvivalQuestionResponse {
  final int runId;
  final int questionNumber;
  final SurvivalQuestionData question;
  final int timeLimitSeconds;
  final DateTime answerDeadlineUtc;

  const SurvivalQuestionResponse({
    required this.runId,
    required this.questionNumber,
    required this.question,
    required this.timeLimitSeconds,
    required this.answerDeadlineUtc,
  });

  factory SurvivalQuestionResponse.fromJson(Map<String, dynamic> json) {
    return SurvivalQuestionResponse(
      runId: json['run_id'] as int,
      questionNumber: json['question_number'] as int,
      question: SurvivalQuestionData.fromJson(
          json['question'] as Map<String, dynamic>),
      timeLimitSeconds: json['time_limit_seconds'] as int,
      answerDeadlineUtc: DateTime.parse(json['answer_deadline_utc'] as String),
    );
  }
}

/// Summary of a completed survival run.
class SurvivalRunSummary {
  final int runId;
  final int questionsAnswered;
  final double totalScore;

  const SurvivalRunSummary({
    required this.runId,
    required this.questionsAnswered,
    required this.totalScore,
  });

  factory SurvivalRunSummary.fromJson(Map<String, dynamic> json) {
    return SurvivalRunSummary(
      runId: json['run_id'] as int,
      questionsAnswered: json['questions_answered'] as int,
      totalScore: (json['total_score'] as num).toDouble(),
    );
  }
}

/// Response for survival answer submission.
class SurvivalAnswerResponse {
  final bool passed;
  final double score;
  final double percentile;
  final double passThreshold;
  final AnswerValue correctAnswer;
  final AnswerValue convertedCorrectAnswer;
  final AnswerValue userAnswer;
  final int totalQuestions;
  final double totalScore;
  final SurvivalRunSummary? runSummary;
  final String? aiOverview;

  const SurvivalAnswerResponse({
    required this.passed,
    required this.score,
    required this.percentile,
    required this.passThreshold,
    required this.correctAnswer,
    required this.convertedCorrectAnswer,
    required this.userAnswer,
    required this.totalQuestions,
    required this.totalScore,
    this.runSummary,
    this.aiOverview,
  });

  factory SurvivalAnswerResponse.fromJson(Map<String, dynamic> json) {
    return SurvivalAnswerResponse(
      passed: json['passed'] as bool,
      score: (json['score'] as num).toDouble(),
      percentile: (json['percentile'] as num).toDouble(),
      passThreshold: (json['pass_threshold'] as num).toDouble(),
      correctAnswer: _parseAnswerValue(json['correct_answer']),
      convertedCorrectAnswer:
          _parseAnswerValue(json['converted_correct_answer']),
      userAnswer: _parseAnswerValue(json['user_answer']),
      totalQuestions: json['total_questions'] as int,
      totalScore: (json['total_score'] as num).toDouble(),
      runSummary: json['run_summary'] != null
          ? SurvivalRunSummary.fromJson(
              json['run_summary'] as Map<String, dynamic>)
          : null,
      aiOverview: json['ai_overview'] as String?,
    );
  }
}

/// User's survival mode statistics.
class SurvivalStatsResponse {
  final int totalRuns;
  final int bestStreak;
  final double averageStreak;
  final int totalQuestionsAnswered;

  const SurvivalStatsResponse({
    required this.totalRuns,
    required this.bestStreak,
    required this.averageStreak,
    required this.totalQuestionsAnswered,
  });

  factory SurvivalStatsResponse.fromJson(Map<String, dynamic> json) {
    return SurvivalStatsResponse(
      totalRuns: json['total_runs'] as int,
      bestStreak: json['best_streak'] as int,
      averageStreak: (json['average_streak'] as num).toDouble(),
      totalQuestionsAnswered: json['total_questions_answered'] as int,
    );
  }
}

/// Parse an answer value from JSON (matches backend AnswerBare schema).
AnswerValue _parseAnswerValue(dynamic json) {
  if (json == null) {
    return const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
  }
  final map = json as Map<String, dynamic>;
  // Backend sends float, but AnswerValue.number is int
  final numValue = map['number'] as num? ?? 1;
  final String unit = map['unit'] as String? ?? '';

  // Use decomposeNumber to ensure the number is in [1, 999] range
  // and has the correct order of magnitude (K, M, B, T).
  return decomposeNumber(numValue.toDouble(), unit);
}
