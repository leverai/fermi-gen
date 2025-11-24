import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/animated_like_dislike.dart';

/// Cached state for a single question
class QuestionState {
  final String? questionUid;
  final String questionText;
  final List<String> tags;
  final List<String> units;
  final Map<String, String> unitOptions;
  final Map<String, String> unitAbbreviationToId;
  final Map<String, String> unitIdToAbbreviation;
  final int upvotes;
  final VoteState voteState;
  final String category;
  final AnswerValue? correctAnswer;
  final AnswerValue? userAnswer; // Current user input for this question
  final Map<String, AnswerValue> submittedAnswers; // playerId -> answer
  final Map<String, double> scores; // playerId -> score
  final Map<String, int>
      cumulativeScores; // playerId -> cumulative score up to this question
  final Map<String, double> percentiles; // playerId -> percentile (0.0-1.0)
  final List<PlayerState> players; // Sorted by rank
  final bool isRevealed;
  final Duration? duration;

  QuestionState({
    this.questionUid,
    this.questionText = '',
    this.tags = const [],
    this.units = const [],
    this.unitOptions = const {},
    this.unitAbbreviationToId = const {},
    this.unitIdToAbbreviation = const {},
    this.upvotes = 0,
    this.voteState = VoteState.none,
    this.category = '',
    this.correctAnswer,
    this.userAnswer,
    this.submittedAnswers = const {},
    this.scores = const {},
    this.cumulativeScores = const {},
    this.percentiles = const {},
    this.players = const [],
    this.isRevealed = false,
    this.duration,
  });

  QuestionState copyWith({
    String? questionUid,
    String? questionText,
    List<String>? tags,
    List<String>? units,
    Map<String, String>? unitOptions,
    Map<String, String>? unitAbbreviationToId,
    Map<String, String>? unitIdToAbbreviation,
    int? upvotes,
    VoteState? voteState,
    String? category,
    AnswerValue? correctAnswer,
    AnswerValue? userAnswer,
    Map<String, AnswerValue>? submittedAnswers,
    Map<String, double>? scores,
    Map<String, int>? cumulativeScores,
    Map<String, double>? percentiles,
    List<PlayerState>? players,
    bool? isRevealed,
    Duration? duration,
  }) {
    return QuestionState(
      questionUid: questionUid ?? this.questionUid,
      questionText: questionText ?? this.questionText,
      tags: tags ?? this.tags,
      units: units ?? this.units,
      unitOptions: unitOptions ?? this.unitOptions,
      unitAbbreviationToId: unitAbbreviationToId ?? this.unitAbbreviationToId,
      unitIdToAbbreviation: unitIdToAbbreviation ?? this.unitIdToAbbreviation,
      upvotes: upvotes ?? this.upvotes,
      voteState: voteState ?? this.voteState,
      category: category ?? this.category,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      userAnswer: userAnswer ?? this.userAnswer,
      submittedAnswers: submittedAnswers ?? this.submittedAnswers,
      scores: scores ?? this.scores,
      cumulativeScores: cumulativeScores ?? this.cumulativeScores,
      percentiles: percentiles ?? this.percentiles,
      players: players ?? this.players,
      isRevealed: isRevealed ?? this.isRevealed,
      duration: duration ?? this.duration,
    );
  }
}
