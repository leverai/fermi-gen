import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fermi_frontend/widgets/question_deadline_progress_tracker.dart';

/// Manages game timers including auto-next, review mode activation, and deadline tracking.
class GameTimerManager {
  GameTimerManager({
    required this.onDeadlineExpired,
    required this.notifyListeners,
  });

  final VoidCallback onDeadlineExpired;
  final VoidCallback notifyListeners;

  // Auto-next timer state
  Timer? _autoNextTimer;
  DateTime? _autoNextStartedAt;
  double _autoNextProgress = 0.0;
  static const Duration _autoNextDuration = Duration(seconds: 10);

  // Review mode activation timer (delays activation after final animation)
  Timer? _reviewModeActivationTimer;

  // Deadline progress tracker
  QuestionDeadlineProgressTracker? _deadlineProgressTracker;

  double get autoNextProgress => _autoNextProgress;
  QuestionDeadlineProgressTracker? get deadlineProgressTracker =>
      _deadlineProgressTracker;

  void init() {
    _deadlineProgressTracker = QuestionDeadlineProgressTracker();
    _deadlineProgressTracker?.setOnExpired(onDeadlineExpired);
  }

  void dispose() {
    _autoNextTimer?.cancel();
    _reviewModeActivationTimer?.cancel();
    _deadlineProgressTracker?.dispose();
  }

  // --- Auto-Next Timer Logic ---

  void startAutoNextTimer({
    required VoidCallback onComplete,
    required bool Function() shouldContinue,
  }) {
    cancelAutoNextTimer();
    _autoNextStartedAt = DateTime.now();
    _autoNextProgress = 0.0;

    _autoNextTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!shouldContinue()) {
        cancelAutoNextTimer();
        return;
      }

      final elapsed = DateTime.now().difference(_autoNextStartedAt!);
      _autoNextProgress =
          (elapsed.inMilliseconds / _autoNextDuration.inMilliseconds)
              .clamp(0.0, 1.0);

      if (_autoNextProgress >= 1.0) {
        cancelAutoNextTimer();
        onComplete();
      }
      notifyListeners();
    });
  }

  void cancelAutoNextTimer() {
    _autoNextTimer?.cancel();
    _autoNextTimer = null;
    _autoNextProgress = 0.0;
    notifyListeners();
  }

  // --- Review Mode Timer Logic ---

  void scheduleReviewModeActivation(VoidCallback onActivate) {
    _reviewModeActivationTimer?.cancel();
    _reviewModeActivationTimer =
        Timer(const Duration(milliseconds: 1000), onActivate);
  }

  void cancelReviewModeTimer() {
    _reviewModeActivationTimer?.cancel();
    _reviewModeActivationTimer = null;
  }

  // --- Deadline Timer Logic ---

  void startDeadlineTimer(Duration duration) {
    _deadlineProgressTracker?.start(duration, onExpired: onDeadlineExpired);
  }

  void stopDeadlineTimer() {
    _deadlineProgressTracker?.stop();
  }

  void resetDeadlineTimer() {
    _deadlineProgressTracker?.reset();
  }
}
