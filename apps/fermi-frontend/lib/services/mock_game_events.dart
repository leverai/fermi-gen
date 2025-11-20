import 'dart:async';
import 'package:fermi_frontend/services/game_events.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/om_constants.dart';

/// A simple in-memory mock that simulates backend reveal behavior.
class MockGameEvents implements GameEvents {
  final StreamController<RevealEvent> _revealController =
      StreamController<RevealEvent>.broadcast();

  /// Optional predefined correct answers by question index for demo stability.
  /// If provided, these will be emitted on force-reveal; otherwise a mock value is used.
  final Map<int, AnswerValue>? predefinedAnswers;

  MockGameEvents({this.predefinedAnswers});

  @override
  Stream<RevealEvent> get revealStream => _revealController.stream;

  @override
  Stream<RevealEvent> revealsForQuestion(int questionIndex) =>
      revealStream.where((e) => e.questionIndex == questionIndex);

  /// Simulated correct answer generator for demo purposes.
  AnswerValue _computeMockCorrectAnswer(int questionIndex, AnswerValue seed) {
    // Nudge value deterministically based on index
    final int within = ((seed.number + 111 + (questionIndex * 7)) % 999);
    final int nextWithin = within == 0 ? 999 : within;
    int omIndex = orderOfMagnitudeSymbols.indexOf(seed.orderOfMagnitude);
    if (nextWithin < seed.number &&
        omIndex < orderOfMagnitudeSymbols.length - 1) {
      omIndex += 1;
    }
    return AnswerValue(
      number: nextWithin,
      orderOfMagnitude: orderOfMagnitudeSymbols[omIndex],
      unit: seed.unit,
    );
  }

  /// For demo: on force reveal, emit a reveal event after a short delay.
  /// Optionally pass a [seed] for the current user answer to shape the output.
  void emitMockReveal(
    String gameId,
    int questionIndex,
    AnswerValue seed,
  ) {
    Future.delayed(const Duration(milliseconds: 500), () {
      final correct = predefinedAnswers != null &&
              predefinedAnswers!.containsKey(questionIndex)
          ? predefinedAnswers![questionIndex]!
          : _computeMockCorrectAnswer(questionIndex, seed);
      _revealController.add(
        RevealEvent(questionIndex: questionIndex, correctAnswer: correct),
      );
    });
  }

  @override
  void requestForceReveal(String gameId, int questionIndex) {
    // Without a seed, emit a baseline value.
    emitMockReveal(
      gameId,
      questionIndex,
      const AnswerValue(number: 500, orderOfMagnitude: '', unit: ''),
    );
  }
}
