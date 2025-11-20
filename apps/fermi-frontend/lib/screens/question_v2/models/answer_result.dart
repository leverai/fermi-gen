import 'package:fermi_frontend/models/answer_value.dart';

class AnswerResult {
  final AnswerValue userAnswer;
  final AnswerValue? correctAnswer;
  final int index;

  const AnswerResult({
    required this.userAnswer,
    required this.index,
    this.correctAnswer,
  });
}
