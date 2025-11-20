import 'dart:async';
import 'package:flutter/foundation.dart';

/// A simple, lifecycle-safe deadline timer for a single question.
///
/// Decouples logical deadline from any visual progress indicators.
/// Once started, it will invoke [onDeadline] exactly once after [duration]
/// unless cancelled or disposed earlier.
class QuestionDeadlineTimer {
  final Duration duration;
  final VoidCallback onDeadline;

  Timer? _timer;
  bool _handled = false;

  QuestionDeadlineTimer({
    required this.duration,
    required this.onDeadline,
  });

  /// Starts the deadline countdown. Calling multiple times restarts the timer.
  void start() {
    _timer?.cancel();
    _handled = false;
    _timer = Timer(duration, _handleDeadline);
  }

  /// Cancels the deadline if it hasn't fired yet.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _handleDeadline() {
    if (_handled) return;
    _handled = true;
    onDeadline();
  }

  /// Disposes the underlying timer.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
