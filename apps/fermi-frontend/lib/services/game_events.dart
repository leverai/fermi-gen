import 'dart:async';
import 'package:fermi_frontend/models/answer_value.dart';

/// Event emitted when the backend reveals the correct answer for a question.
class RevealEvent {
  final int questionIndex;
  final AnswerValue correctAnswer;

  RevealEvent({required this.questionIndex, required this.correctAnswer});
}

/// Interface for game-related realtime events (mocked for demo).
abstract class GameEvents {
  /// Stream of all reveal events. Consumers should scope by [questionIndex].
  Stream<RevealEvent> get revealStream;

  /// Convenience: a scoped stream for a specific question index.
  Stream<RevealEvent> revealsForQuestion(int questionIndex) =>
      revealStream.where((e) => e.questionIndex == questionIndex);

  /// Request the backend to force a reveal for the given [gameId] and [questionIndex].
  /// In demo, a mock will emit a reveal shortly after.
  void requestForceReveal(String gameId, int questionIndex);
}
