# Bug Report: Stats Not Refreshing Immediately After Playing DQ

## Problem

After playing a Daily Question (DQ), stats on the Me Tab take 20-30 seconds to update. User reports seeing repeated `MainScreenController: Skipping refresh (too soon)` messages in the console.

## Observed Behavior

1. User opens MainScreen (Games Tab)
2. User taps on DQ card, plays and submits answer
3. User returns to MainScreen and switches to Me Tab
4. Stats show **stale data** (old values)
5. Console shows: `MainScreenController: Skipping refresh (too soon)` repeated many times
6. Stats eventually update after ~30 seconds

## Expected Behavior

Stats should update **immediately** after playing DQ, without any delay.


**Attempted fix**: Added `force: true` to the call in `daily_question_carousel.dart` line 108, but this didn't resolve the issue

## Investigation Required

A thorough audit is needed to understand and simplify the refresh system. Key areas to investigate:

### 0. Understand the Navigation Flow TO and FROM the Main Screen

This includes:
-   Creating a Party Game
-   Joining a Party Game
-   Leaving a Party Game
-   Finishing a Party Game
-   Taking a Daily Question from the DQ card in the carousel
-   Taking a Daily Question from the archive sheet
-   Taking a Daily Question from an invite link
-   Leaving a Daily Question
-   Finishing a Daily Question


### 1. Identify All Refresh Triggers

Map every location that calls `refreshInBackground()` or similar refresh methods:
- `main_screen.dart` - `initState`, `didChangeAppLifecycleState`, `_onBottomNavTapped`, `.then()` callback after party game
- `daily_question_carousel.dart` - `.then()` callbacks after DQ navigation
- Any other screens or controllers

### 2. Trace the Actual Code Path

Add detailed logging or use debugger to trace:
- Which specific code path is executed when returning from DQ
- Where `_lastRefreshTime` is being set
- Why the "Skipping refresh" message appears even after the fix

### 3. Understand the Widget Lifecycle

The DQ flow involves:
- `PreDailyQuestionScreen` (uses `pushReplacement`)
- `DailyQuestionScreen`
- Navigation back to `MainScreen`

Ask: Is `MainScreen` being **recreated** or **resumed**? This affects whether `initState` runs again.

### 4. Consider Alternative Patterns

The current approach ties refresh to navigation callbacks (`.then()`). Consider:
- **Pull-to-refresh**: User-initiated, explicit refresh
- **Stream/listener pattern**: Stats update via a stream when backend changes
- **Single responsibility**: One clear place that handles refresh, not scattered across callbacks

## Recommended Refactoring Goals

1. **Simplicity**: Single, clear mechanism for triggering stats refresh
2. **Robustness**: Stats always reflect the latest backend state after any mutation
3. **Debuggability**: Easy to trace why a refresh did or didn't happen
4. **No hidden debounce surprises**: If debounce is needed, make it obvious and configurable

## Files to Review

- `lib/screens/main/main_screen.dart` - MainScreen widget and refresh triggers
- `lib/screens/main/main_screen_controller.dart` - `refreshInBackground()` implementation
- `lib/screens/main/widgets/daily_question_carousel.dart` - DQ navigation and `.then()` callbacks
- `lib/screens/daily_question/daily_question_screen.dart` - DQ submission flow
- `lib/controllers/daily_question_controller.dart` - `refreshArchiveAndSubscribe()`
- Whatever you think is relevant

## Testing Verification

After fixing, verify all these scenarios update stats immediately. I will be confirming on the Android emulator.
