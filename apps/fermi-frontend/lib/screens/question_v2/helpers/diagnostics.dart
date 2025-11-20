import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// Module-local diagnostics toggle for the question screen.
/// Set to false to silence logs without code churn.
const bool kQuestionDiagnostics = true;

void qlog(String message) {
  if (kDebugMode && kQuestionDiagnostics) {
    debugPrint(message);
  }
}
