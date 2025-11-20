import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Tracks question deadline progress and provides a 0.0-1.0 progress value
/// that can be used with CircularDeterminateSpinner.
/// Progress starts at 0.0 and counts up to 1.0 as time elapses.
class QuestionDeadlineProgressTracker extends ChangeNotifier {
  double _progress = 0.0;
  bool _isActive = false;
  Timer? _timer;
  Duration? _currentDuration;
  DateTime? _startTime;
  VoidCallback? _onExpired;

  double get progress => _progress;
  bool get isActive => _isActive;

  /// Set callback to be called when deadline expires
  void setOnExpired(VoidCallback? callback) {
    _onExpired = callback;
  }

  void start(Duration duration, {VoidCallback? onExpired}) {
    if (onExpired != null) {
      _onExpired = onExpired;
    }
    if (duration.inMilliseconds <= 0) {
      stop();
      return;
    }

    // If already running with the same duration, don't restart
    if (_isActive && _currentDuration == duration && _startTime != null) {
      return;
    }

    // Cancel any existing timer
    _timer?.cancel();
    _timer = null;

    _isActive = true;
    _currentDuration = duration;
    _startTime = DateTime.now();
    _progress = 0.0; // Start at 0% and count up
    notifyListeners();

    // Use a timer to update progress
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isActive) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_startTime!);

      if (elapsed >= duration) {
        _progress = 1.0;
        _isActive = false;
        notifyListeners();
        timer.cancel();
        _timer = null;
        // Call expired callback if set
        _onExpired?.call();
        return;
      }

      _progress = elapsed.inMilliseconds / duration.inMilliseconds;
      notifyListeners();
    });
  }

  /// Stops the timer but preserves the current progress value.
  ///
  /// This is used when the timer should stop (e.g., all players have answered)
  /// but we want to preserve the progress state for display purposes.
  /// Progress will be reset to 0.0 when [start] is called for a new question.
  ///
  /// Use [reset] if you need to fully reset progress to 0.0.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isActive = false;
    _currentDuration = null;
    _startTime = null;
    // Don't reset progress - preserve it so player rings don't show as full
    // when the timer stops. Progress will be reset when start() is called.
    _onExpired = null; // Clear callback when stopped
    notifyListeners();
  }

  /// Fully resets the tracker, including progress to 0.0.
  ///
  /// Use this when you need to completely reset the tracker state.
  /// For normal stopping that preserves progress, use [stop] instead.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _isActive = false;
    _currentDuration = null;
    _startTime = null;
    _progress = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
