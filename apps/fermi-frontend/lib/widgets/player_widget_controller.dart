class PlayerWidgetController {
  void Function(int newRoundScore)? _setRoundScore;
  void Function(int newScore)? _setScore;
  void Function()? _triggerConfetti;
  void Function()? _clearConfetti;
  int? _lastRoundScore;
  int? _lastScore;
  bool _pendingConfetti = false;

  void bind({
    required void Function(int newRoundScore) setRoundScore,
    void Function(int newScore)? setScore,
    required void Function() triggerConfetti,
    required void Function() clearConfetti,
  }) {
    _setRoundScore = setRoundScore;
    _setScore = setScore;
    _triggerConfetti = triggerConfetti;
    _clearConfetti = clearConfetti;

    // If updates arrived before the widget bound to this controller, replay them
    // so the UI starts in a consistent state.
    if (_lastRoundScore != null) {
      _setRoundScore?.call(_lastRoundScore!);
    }
    if (_lastScore != null) {
      _setScore?.call(_lastScore!);
    }
    if (_pendingConfetti) {
      _triggerConfetti?.call();
      _pendingConfetti = false;
    }
  }

  void dispose() {
    _setRoundScore = null;
    _setScore = null;
    _triggerConfetti = null;
    _clearConfetti = null;
  }

  void setRoundScore(int newRoundScore) {
    _lastRoundScore = newRoundScore;
    final fn = _setRoundScore;
    if (fn != null) fn(newRoundScore);
  }

  /// Set the total score (for review mode - animates to the new score)
  void setScore(int newScore) {
    _lastScore = newScore;
    final fn = _setScore;
    if (fn != null) fn(newScore);
  }

  void triggerConfetti() {
    _pendingConfetti = true;
    final fn = _triggerConfetti;
    if (fn != null) {
      fn();
      _pendingConfetti = false;
    }
  }

  void clearConfetti() {
    final fn = _clearConfetti;
    if (fn != null) fn();
  }
}
