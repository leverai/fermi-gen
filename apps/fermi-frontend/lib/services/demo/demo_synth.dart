import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/om_constants.dart';

/// Deterministic demo helpers extracted out of production widgets.
/// Keep demo-only logic here.

int computeScoreIncrement(int questionIndex, int playerIndex) {
  // Deterministic 1k..10k based on question and player index
  final int step = ((questionIndex + (playerIndex * 3)) % 10) + 1; // 1..10
  return step * 1000;
}

/// Demo helper: synthesize submitted answers for non-local players.
/// Index mapping: 0 = host, 1 = other, 2 = local user in this demo.
AnswerValue synthesizeSubmittedAnswer(
  AnswerValue base,
  int playerIndex,
  int localPlayerIndex,
) {
  if (playerIndex == localPlayerIndex) return base;
  int nextNumber = ((base.number + (playerIndex + 1) * 37) % 999);
  if (nextNumber == 0) nextNumber = 999;
  int omIndex = orderOfMagnitudeSymbols.indexOf(base.orderOfMagnitude);
  if (playerIndex == 0 &&
      omIndex < orderOfMagnitudeSymbols.length - 1 &&
      nextNumber < base.number) {
    omIndex += 1;
  }
  return AnswerValue(
    number: nextNumber,
    orderOfMagnitude: orderOfMagnitudeSymbols[omIndex],
    unit: base.unit,
  );
}
