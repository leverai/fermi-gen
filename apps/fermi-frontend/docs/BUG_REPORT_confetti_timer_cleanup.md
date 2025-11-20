# Bug Report: Confetti Timer Cleanup in Tests

## Issue
The `PlayerConfettiOverlay` widget creates an 8-second timer in `initState` using `Future.delayed` that does not get cancelled when the widget is disposed. This causes test failures because the Flutter test framework requires all timers to be completed before a test ends.

## Location
- File: `lib/widgets/player_confetti_overlay.dart`
- Lines: 44-48

## Current Implementation
```dart
const cleanupDelay = Duration(seconds: 8);
Future.delayed(cleanupDelay, () {
  if (mounted) {
    widget.onComplete?.call();
  }
});
```

## Problem
1. The `Future.delayed` creates a timer that is not stored or cancelled
2. When the widget is disposed, the timer continues running
3. The Flutter test framework detects pending timers and fails the test
4. This affects widget tests that verify confetti functionality

## Expected Behavior
The timer should be cancelled when the widget is disposed to prevent test failures and ensure proper cleanup.

## Proposed Solution
Store the timer in a variable and cancel it in `dispose()`:

```dart
Timer? _cleanupTimer;

@override
void initState() {
  super.initState();
  // ... existing code ...
  const cleanupDelay = Duration(seconds: 8);
  _cleanupTimer = Timer(cleanupDelay, () {
    if (mounted) {
      widget.onComplete?.call();
    }
  });
}

@override
void dispose() {
  _cleanupTimer?.cancel();
  _controller.dispose();
  super.dispose();
}
```

## Affected Tests
- `test/widget/widgets/player_widget_test.dart`:
  - "should trigger confetti for highest scorer"
  - "should clip confetti to widget bounds"
  - "should clear confetti on next question"
  - "should trigger confetti on controller call"

## Impact
- **Severity**: Medium (affects testability, not production functionality)
- **Priority**: Medium (should be fixed to enable proper testing)

## Notes
This is a test-only issue. The timer completes naturally in production, but the test framework's strict timer checking causes failures.
