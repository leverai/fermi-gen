# Bug Report: Answer Widget Not Preserving Revealed State

## Date
November 17, 2025

## Status
**PARTIALLY RESOLVED** - Significant progress made, but 3 issues remain

**CURRENT STATE**: The codebase has been updated with fixes that partially resolve the issue. Color preservation is working, but value preservation and some edge cases still need attention.

## Problem Statement

Answer widgets fail to preserve their revealed state (correct answer value and score-based color) in several scenarios:

1. **Leaving Card Reset (PARTIALLY FIXED)**: When a question reveals and the user/host presses "Next" to move to the next question, the answer widget in the **leaving card** (the card transitioning out of view) retains its color ✅ but loses its value ❌ (resets to default values: number=1, empty OM, default unit).

2. **Review Mode Reset (PARTIALLY FIXED)**: When entering review mode after completing a game, all answer widgets except the last card reset to default values and colors ❌. The last card correctly maintains its state ✅.

3. **Final Card Animation (INTERMITTENT)**: The final card's answer sometimes does not animate to the correct answer ❌.

**Expected Behavior**:
- When a question reveals, it should show the correct answer with a score-based color
- When navigating away from that question, it should **maintain** that revealed state
- In review mode, all revealed questions should display their correct answers with score-based colors

**Actual Behavior**:
- Answer widgets reset to default values (1, empty OM, first unit) when:
  - The question becomes non-current (after pressing "Next")
  - Entering review mode
- The score-based color is lost
- Users see default/placeholder values instead of the answers they submitted and the correct answers

## Reproduction Steps

### Scenario 1: Leaving Card Reset
1. Start a game (live mode)
2. Submit an answer for question 0
3. Question 0 reveals (animation shows correct answer with color)
4. Press "Next" button to move to question 1
5. **BUG**: Look at question 0's card (leaving card) - it shows default values instead of the revealed answer

### Scenario 2: Review Mode Reset
1. Play through an entire game (all questions)
2. Each question reveals with correct answer and color
3. Game finishes and enters review mode
4. **BUG**: All question cards show default values and no colors, instead of their revealed answers

## Architecture Context

### Application Structure

This is a **Flutter multiplayer game application** with real-time synchronization. The app has two modes:

1. **Live Mode**: Active game where players answer questions, submit answers, and see reveals
2. **Review Mode**: After game completion, players can swipe through all questions to review their performance

### Component Hierarchy

```
QuestionScreenV2 (StatefulWidget)
├── PageView (carousel of questions)
│   └── CarouselPageWrapper (keeps widgets alive when scrolled away)
│       └── Column (for each question)
│           └── GameCard (question + answer display)
│               ├── QuestionWidget (displays question text)
│               └── AnswerWidget (controlled component)
│                   ├── DigitWheels (number input)
│                   ├── OmLabel (order of magnitude selector)
│                   └── UnitTape (unit selector)
└── QuestionScreenV2Controller (state management)
```

### Key Components

#### 1. QuestionScreenV2Controller
**File**: `apps/fermi-frontend/lib/screens/question_v2/question_screen_v2_controller.dart`

Central state manager that:
- Manages game state for all questions
- Caches historical data in `_questionStates` map (per-question state)
- Provides `AnswerController` for the current question
- Computes display values via `getDisplayAnswer(index)`
- Tracks animation state in `_animationProgress` and `_animatingQuestionIndex`

**Key Fields**:
- `_questionStates: Map<int, QuestionState>` - Per-question state cache
- `_animationProgress: Map<int, AnswerValue>` - Animation progress tracking
- `_animatingQuestionIndex: int?` - Which question is animating
- `_currentIndex: int` - Currently displayed question
- `_isReviewMode: bool` - Whether in review mode
- `_answerController: AnswerController` - Shared controller for current question

**Key Methods**:
- `getDisplayAnswer(int index)`: Computes what value to display for a question
  - Priority 1: Animation progress (if actively animating)
  - Priority 2: Revealed answer (for revealed questions)
  - Priority 3: User's current input (for current editable question)
  - Priority 4: Default fallback
- `getRevealedAnswer(int index)`: Returns the correct answer for a revealed question
- `getRevealedColor(int index)`: Returns score-based color for a revealed question

#### 2. QuestionState
**File**: `apps/fermi-frontend/lib/screens/question_v2/question_screen_v2_controller.dart` (lines 14-102)

Immutable state object for each question:
- `questionText: String`
- `units: List<String>`
- `correctAnswer: AnswerValue?` - The correct answer (set when revealed)
- `userAnswer: AnswerValue?` - User's current input for this question
- `submittedAnswers: Map<String, AnswerValue>` - Per-player submitted answers
- `scores: Map<String, double>` - Per-player scores
- `isRevealed: bool` - Whether this question has been revealed
- Plus other metadata (tags, upvotes, etc.)

#### 3. AnswerWidget
**File**: `apps/fermi-frontend/lib/widgets/answer_widget.dart`

A **fully controlled component** that displays answer values. It has two modes of operation:

**Mode 1: Controller-Bound (Current Question in Live Mode)**
- `controller` prop is bound
- Controller manages animations via `reveal()` method
- Widget responds to user input and notifies parent via `onChanged`

**Mode 2: Prop-Controlled (Non-Current Questions, Review Mode)**
- `controller` prop is `null`
- Widget displays `value` prop
- Can also display revealed state via `revealedAnswer` + `revealedColor` props

**Key Props**:
- `value: AnswerValue` - Current display value (always required)
- `controller: AnswerController?` - Binds widget to controller for animations
- `revealedAnswer: AnswerValue?` - If provided, shows this as the revealed answer
- `revealedColor: Color?` - Score-based color to display for revealed state
- `editable: bool` - Whether user can edit

**Key Internal State**:
- `_digitsController, _omController, _unitController` - Sub-controllers for UI elements
- `_digitsOverrideColor: Color?` - Color to display for revealed state
- `_isRevealing: bool` - Whether currently revealing
- `_isControllerAnimating: bool` - Whether controller is animating

**Key Methods**:
- `didUpdateWidget()`: Syncs internal state when props change
- `_jumpToRevealedValue()`: Jumps to revealed state without animation
- `_syncControllersToValue()`: Syncs sub-controllers to `value` prop
- `_resetVisualState()`: Resets colors and revealed flags

#### 4. AnswerController
**File**: `apps/fermi-frontend/lib/widgets/answer_widget.dart` (lines 9-99)

Shared controller that allows external code (the screen controller) to:
- Read current value
- Jump to a value instantly
- Animate to a value
- Reveal answer with animation and color
- Reset visual state

**Key Methods**:
- `reveal(target, duration, color, {onProgress, onComplete})` - Animates to revealed state
- `jumpTo(target)` - Jumps to value instantly
- `resetVisualState()` - Clears revealed colors

### Data Flow: Question Reveal

1. **Backend Event**: Game server sends reveal event
2. **Controller**: `_handleReveal()` is called
   - Sets `QuestionState.isRevealed = true`
   - Sets `QuestionState.correctAnswer`
   - For current question: calls `_answerController.reveal()`
3. **Widget Animation** (if controller bound):
   - `AnswerWidget._revealToValue()` animates values
   - Calls `updateDisplayAnswer()` during animation with progress
   - Sets `_digitsOverrideColor` to score-based color
   - Sets `_isRevealing = true`, then `false` when done
4. **Widget Rebuild**: Flutter rebuilds with updated state

### Data Flow: Question Navigation

1. **User/Host**: Presses "Next" button
2. **Backend**: Updates `questionNumber` in game state
3. **Controller**: `_onQuestionIndexChanged(newIndex)` is called
   - Clears `_animationProgress` for old question
   - Updates `_currentIndex`
   - New question becomes current
4. **Screen Build**: `_buildGameCard()` for each question
   - Computes `displayAnswer = _controller.getDisplayAnswer(index)`
   - Determines `revealedAnswer` and `revealedColor` to pass
   - For current question: binds `answerController`
   - For non-current questions: `answerController = null`
5. **Widget Rebuild**: `AnswerWidget.didUpdateWidget()` is called
   - Detects controller unbinding (old controller bound, new is null)
   - Should preserve revealed state but **FAILS**

### Data Flow: Review Mode Entry

1. **Backend**: Game state changes to `GameState.gameFinished`
2. **Controller**: `_isReviewMode = true`
   - Clears `_animationProgress` and `_animatingQuestionIndex`
3. **Screen Build**: All questions built with `answerController = null`
4. **Widget Rebuild**: All widgets should show revealed state but **FAIL**

## Previous Bug History

This bug is related to a series of state management issues that have been addressed:

1. **Mirror Text State Issue** (FIXED): Per-question mirror text state was leaking
2. **Last Question Animation** (FIXED): Last question animation wasn't working correctly
3. **Answer Value Leakage** (PARTIALLY FIXED): Answer values were leaking between questions
   - Fix: Changed from shared `_currentAnswer` to per-question `QuestionState.userAnswer`
   - Fix: Clear animation state when entering review mode

See: `BUG_REPORT_ANSWER_WIDGET_VALUE_LEAKAGE.md` for full history.

## Current Implementation State

**NOTE**: This section describes the ORIGINAL code state before any fix attempts. All changes from fix attempts have been reverted, so this is the current state of the codebase.

### Controller: getDisplayAnswer() Logic

**File**: `apps/fermi-frontend/lib/screens/question_v2/question_screen_v2_controller.dart` (lines 215-283)

```dart
AnswerValue getDisplayAnswer(int index) {
  final state = _questionStates[index];
  final bool isCurrentQuestion = index == _currentIndex;
  final bool showFeedback = state?.isRevealed ?? false;

  // Priority 1: Animation progress (if question is actively animating)
  if (_animatingQuestionIndex == index &&
      _animationProgress.containsKey(index)) {
    return _animationProgress[index]!;
  }

  // Priority 2: Revealed answer (for revealed questions)
  if (showFeedback && state != null) {
    final revealed = getRevealedAnswer(index);
    if (revealed != null) {
      return revealed;
    }
    // Fallbacks if revealed answer not available
    if (state.userAnswer != null) {
      return state.userAnswer!;
    }
    final myId = realtime.currentPlayerId;
    final submittedAnswer = state.submittedAnswers[myId];
    if (submittedAnswer != null) {
      return submittedAnswer;
    }
  }

  // Priority 3: User's current input (for current editable question in live mode ONLY)
  if (isCurrentQuestion && !_isReviewMode && !showFeedback) {
    // ... initialization logic ...
    return state.userAnswer!;
  }

  // Priority 4: Default fallback
  return const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
}
```

### Controller: getRevealedAnswer() Logic

**File**: `apps/fermi-frontend/lib/screens/question_v2/question_screen_v2_controller.dart` (lines 1488-1517)

```dart
AnswerValue? getRevealedAnswer(int index) {
  final state = _questionStates[index];
  if (state == null || !state.isRevealed) {
    return null;
  }

  // For revealed questions, we must return a valid answer
  if (state.correctAnswer != null) {
    return _toDisplayAnswer(state.correctAnswer!, state);
  }

  // Fallbacks with debug assertions
  // ...
}
```

### Screen: Prop-Passing Logic

**File**: `apps/fermi-frontend/lib/screens/question_v2/question_screen_v2.dart` (lines 397-408)

```dart
// Get display answer from controller (single source of truth)
final AnswerValue displayAnswer = _controller.getDisplayAnswer(index);

// CRITICAL: Always pass revealed props when question is revealed
final revealedAnswer =
    showFeedback ? _controller.getRevealedAnswer(index) : null;

final revealedColor =
    showFeedback ? _controller.getRevealedColor(index) : null;
```

Then passes to GameCard which passes to AnswerWidget:
```dart
AnswerWidget(
  value: currentAnswer,  // displayAnswer from controller
  controller: answerController,  // null for non-current questions
  revealedAnswer: revealedAnswer,
  revealedColor: revealedColor,
  editable: isCurrentQuestion && !_isReviewMode && !showFeedback,
  // ...
)
```

### Widget: didUpdateWidget() Logic

**File**: `apps/fermi-frontend/lib/widgets/answer_widget.dart` (lines 199-276)

```dart
@override
void didUpdateWidget(covariant AnswerWidget oldWidget) {
  super.didUpdateWidget(oldWidget);

  final bool hasRevealedProps = widget.revealedAnswer != null &&
                                 widget.revealedColor != null &&
                                 !widget.editable;

  final bool hadRevealedProps = oldWidget.revealedAnswer != null &&
                                 oldWidget.revealedColor != null &&
                                 !oldWidget.editable;

  // Handle controller binding changes
  final bool controllerChanged = oldWidget.controller != widget.controller;
  final bool controllerUnbound = oldWidget.controller != null && widget.controller == null;

  if (controllerChanged) {
    // When controller unbinds, immediately stop any ongoing animation
    if (controllerUnbound) {
      _isRevealing = false;
      _isControllerAnimating = false;
    }

    // Bind/unbind controller
    widget.controller?._bind(...);
  }

  // Determine if we need to update the widget's display
  final bool valueChanged = oldWidget.value != widget.value;
  final bool revealedPropsChanged =
      oldWidget.revealedAnswer != widget.revealedAnswer ||
      oldWidget.revealedColor != widget.revealedColor;

  // If controller is bound, it manages all state - don't interfere
  if (widget.controller != null) {
    return;
  }

  // If still animating, wait for it to complete
  // EXCEPTION: If controller was just unbound, we've already stopped the animation above
  if (!controllerUnbound && (_isRevealing || _isControllerAnimating)) {
    return;
  }

  // Sync to revealed state if revealed props are provided
  if (hasRevealedProps) {
    // Jump to revealed state if:
    // 1. Revealed props changed
    // 2. Controller was just unbound (transition from current to non-current)
    // 3. Value changed (might be transitioning to revealed state)
    if (revealedPropsChanged ||
        controllerUnbound ||
        (valueChanged && !hadRevealedProps)) {
      _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
    }
  }
  // Otherwise, sync to value prop
  else {
    // Reset visual state if revealed props were removed
    if (hadRevealedProps && !hasRevealedProps) {
      _resetVisualState();
    }

    // Sync controllers to value prop if:
    // 1. Value changed
    // 2. Controller was just unbound
    // 3. Transitioning from revealed to non-revealed
    if (valueChanged ||
        controllerUnbound ||
        (hadRevealedProps && !hasRevealedProps)) {
      _syncControllersToValue();
    }
  }
}
```

### Widget: Unique Keys

**File**: `apps/fermi-frontend/lib/screens/question_v2/question_screen_v2.dart` (lines 492-496)

Each AnswerWidget has a unique key per question:
```dart
answerWidgetKey: isCurrentQuestion
    ? (widget.answerWidgetKey ?? ValueKey('answer_$index'))
    : ValueKey('answer_$index'),
```

### Widget: Keep-Alive

**File**: `apps/fermi-frontend/lib/screens/question_v2/widgets/carousel_page_wrapper.dart`

PageView items are wrapped with `AutomaticKeepAliveClientMixin` (`wantKeepAlive => true`), which keeps widgets alive when scrolled away from view. This means widgets don't get disposed and recreated when navigating between questions.

## Fix Attempts Made

### Attempt 1: Clear Animation State When Entering Review Mode
**Files Modified**: `question_screen_v2_controller.dart` (lines 406-415)

**Changes**:
```dart
// Determine if we're in review mode
final bool wasReviewMode = _isReviewMode;
_isReviewMode = snapshot.state == GameState.questionLastFinished ||
    snapshot.state == GameState.gameFinished;

// Clear animation state when entering review mode
if (_isReviewMode && !wasReviewMode) {
  _animatingQuestionIndex = null;
  _animationProgress.clear();
}
```

**Result**: Tests pass, but real app still shows bug. Animation state clearing alone is insufficient.

### Attempt 2: Stop Animation Flags When Controller Unbinds
**Files Modified**: `answer_widget.dart` (lines 220-228)

**Changes**: When controller unbinds, immediately set `_isRevealing = false` and `_isControllerAnimating = false` to allow widget to sync to revealed state.

**Result**: Tests pass, but real app still shows bug.

### Attempt 3: Always Pass Revealed Props
**Files Modified**: `question_screen_v2.dart` (lines 404-408)

**Original Logic**:
```dart
final bool shouldPassRevealedAnswer = showFeedback &&
    (!isCurrentQuestion || _controller.isReviewMode);

final revealedAnswer =
    shouldPassRevealedAnswer ? _controller.getRevealedAnswer(index) : null;
```

**Changed To**:
```dart
// Always pass revealed props when question is revealed
final revealedAnswer =
    showFeedback ? _controller.getRevealedAnswer(index) : null;

final revealedColor =
    showFeedback ? _controller.getRevealedColor(index) : null;
```

**Rationale**: Widget needs revealed props to preserve state when controller unbinds.

**Result**:
- ✅ Tests pass
- ❌ Real app: Leaving card still resets
- ❌ Real app: Review mode still shows reset values
- ❌ New bug: Last question animation no longer works

### Attempt 4: Combined Fixes (REVERTED)
All three fixes from attempts 1-3 were applied together. Tests passed but real app still showed the bug, plus a new bug with last question animation.

**Result**: All changes reverted. The codebase is back to the original state described in "Current Implementation State" section above.

## Test Coverage

**File**: `apps/fermi-frontend/test/unit/controllers/question_screen_v2_controller_012B/answer_leakage_test.dart`

Tests exist and **all pass**:
1. ✅ Should not leak answer values when navigating between questions
2. ✅ Should preserve per-question answers when navigating back
3. ✅ Should clear animation state when navigating during reveal animation
4. ✅ Should initialize new question with default answer, not previous question answer
5. ✅ Should preserve revealed state when question becomes non-current
6. ✅ Should preserve revealed state in review mode for all questions

**CRITICAL NOTE**: All unit tests pass, but the real app exhibits the bug. This suggests:
- Unit tests may not accurately simulate the real widget lifecycle
- There may be timing issues or widget reuse not captured by tests
- The bug may be in widget rendering, not state management

## Observations from Debugging

### Debug Logging Results (from Attempt 3)

When testing in real app with extensive logging, the following sequence was observed when pressing "Next":

1. Controller correctly computes revealed answer and color
2. Props are passed correctly: `revealedAnswer` and `revealedColor` both set
3. `didUpdateWidget()` is called with correct props
4. Controller unbinds (`controllerUnbound = true`)
5. Animation flags are cleared
6. `hasRevealedProps = true` is computed correctly
7. `_jumpToRevealedValue()` is called with correct values
8. `_jumpToRevealedValue()` completes successfully and sets `_digitsOverrideColor`
9. Widget rebuilds with `_digitsOverrideColor` set correctly
10. **Then**: Widget rebuilds again with `_digitsOverrideColor = null` ❌
11. Subsequent rebuilds maintain `null` color

**Key Finding**: Something resets `_digitsOverrideColor` to `null` after it's successfully set.

### Widget Rebuild Observation

From terminal logs (Attempt 3, lines 947-952):
```
[AnswerWidget.build] Building with value=AnswerValue(number: 600, om: , unit: ), revealedAnswer=AnswerValue(number: 600, om: , unit: ), digitsOverrideColor=Color(0xffbb928b)  ← Correct
[AnswerWidget.build] Building with value=AnswerValue(number: 600, om: , unit: ), revealedAnswer=AnswerValue(number: 600, om: , unit: ), digitsOverrideColor=null  ← RESET!
[AnswerWidget.build] Building with value=AnswerValue(number: 1, om: , unit: in), revealedAnswer=null, digitsOverrideColor=null  ← New question
```

The widget rebuilds multiple times in quick succession, and the color gets reset between rebuilds.

### Revealed Props Before Fix Attempt 3

Before always passing revealed props, when controller unbinds, the widget received:
```
old.revealedAnswer=null, new.revealedAnswer=null  ← Missing!
old.revealedColor=null, new.revealedColor=Color(0xffba928b)  ← Only color passed
hasRevealedProps=false  ← Because both answer AND color are required
```

This explains why the fix seemed necessary - the widget needs both props to preserve revealed state.

## Code Files Affected

### Primary Files
1. `apps/fermi-frontend/lib/screens/question_v2/question_screen_v2_controller.dart` - Controller
2. `apps/fermi-frontend/lib/screens/question_v2/question_screen_v2.dart` - Screen UI
3. `apps/fermi-frontend/lib/widgets/answer_widget.dart` - Widget
4. `apps/fermi-frontend/lib/screens/question_v2/widgets/carousel_page_wrapper.dart` - Keep-alive wrapper

### Test Files
1. `apps/fermi-frontend/test/unit/controllers/question_screen_v2_controller_012B/answer_leakage_test.dart`

### Supporting Files
1. `apps/fermi-frontend/lib/models/answer_value.dart` - AnswerValue model
2. `apps/fermi-frontend/lib/widgets/digit_wheels.dart` - Sub-component
3. `apps/fermi-frontend/lib/widgets/om_label.dart` - Sub-component
4. `apps/fermi-frontend/lib/widgets/unit_tape.dart` - Sub-component

## Environment

- **Framework**: Flutter 3.24.2
- **Platform**: Android (tested), iOS (likely affected)
- **Architecture**: MVVM with ChangeNotifier
- **State Management**: Provider pattern with ChangeNotifier

## Related Documentation

- `BUG_REPORT_ANSWER_WIDGET_VALUE_LEAKAGE.md` - Previous bug and fix attempts
- `BUG_REPORT_CAROUSEL_STATE_FINAL.md` - Carousel state management fixes
- `BUG_REPORT_ANSWER_WIDGET_STATE.md` - Widget state management issues
- `apps/fermi-frontend/docs/ARCHITECTURE.md` - Overall architecture
- `apps/fermi-frontend/docs/TESTS.md` - Testing guidelines

## Success Criteria

The bug will be considered fixed when:

1. ✅ When a question reveals and user presses "Next", the leaving card maintains:
   - ✅ Score-based color (FIXED)
   - ❌ Correct answer values (number, order of magnitude, unit) - STILL BROKEN

2. ✅ When entering review mode, all revealed questions display:
   - ❌ Their correct answers - STILL BROKEN (except last card)
   - ❌ Score-based colors - STILL BROKEN (except last card)
   - ❌ Not default/placeholder values - STILL BROKEN (except last card)

3. ⚠️ Last question animation still works correctly (animates to revealed answer) - INTERMITTENT ISSUE

4. ✅ All existing unit tests continue to pass

5. ✅ No new bugs introduced (answer leakage, animation issues, etc.)

## Notes for Next Agent

### Current Status Summary

**Progress Made**: Color preservation is working ✅, but value preservation is broken ❌

**Key Insight**: The `_hasBeenRevealed` flag successfully preserves visual state (color) but the sub-controllers (`_digitsController`, `_omController`, `_unitController`) are not maintaining their values across rebuilds.

### Critical Issues to Address

1. **Controller State Not Persisting** - The sub-controllers are being reset or not synced correctly:
   - `_jumpToRevealedValue` calls `jumpTo()` on controllers, but values don't persist
   - `_syncControllersToValue` has a guard that prevents syncing when `_hasBeenRevealed` is true, but this might be preventing necessary updates
   - Consider: Do controllers need to be re-synced on every rebuild when revealed?

2. **Review Mode Inconsistency** - Last card works, others don't:
   - Last card maintains state correctly (why?)
   - Other cards reset (why?)
   - Check if `initState` vs `didUpdateWidget` behavior differs
   - Check if revealed props are passed correctly for all cards

3. **Intermittent Animation** - Final card animation sometimes fails:
   - Timing issue between controller binding and reveal event?
   - `_hasBeenRevealed` flag might be set too early?
   - Post-frame callbacks might not be executing?

### Debugging Strategy

1. **Add comprehensive logging**:
   - Log when `_jumpToRevealedValue` is called and what values it receives
   - Log when `_syncControllersToValue` is called and why it's skipped
   - Log controller values before/after `jumpTo()` calls
   - Log `_hasBeenRevealed` flag state changes

2. **Check controller lifecycle**:
   - Are controllers being recreated?
   - Are `jumpTo()` calls actually updating controller state?
   - Do controllers maintain state across rebuilds?

3. **Investigate rebuild sequence**:
   - How many times does `didUpdateWidget` get called?
   - What props are available at each rebuild?
   - Is `_hasBeenRevealed` flag being cleared incorrectly?

### Architecture Considerations

1. **Keep-Alive Behavior** - PageView keeps widgets alive, so `didUpdateWidget()` is called, not `initState()` when navigating. This affects state preservation.

2. **Last Question Special Case** - Last question has special handling to allow animation even in review mode. Any fix must preserve this.

3. **Props vs Internal State** - There's tension between:
   - Widget as "controlled component" (should reflect props)
   - Widget needs internal state for animations and colors
   - Sub-controllers need to maintain their own state

### Potential Solutions to Explore

1. **Re-sync controllers on rebuild** - If revealed, call `_jumpToRevealedValue` on every rebuild (not just once)
2. **Sync in build()** - As fallback, sync controllers in `build()` method if revealed
3. **Check controller state** - Verify controllers actually maintain state after `jumpTo()` calls
4. **Review mode initialization** - Check if `initState` needs special handling for revealed questions in review mode

---

## CURRENT IMPLEMENTATION (Latest Fix Attempt)

### Changes Made

**Date**: Current session
**Status**: Partial success - color preservation working, value preservation needs work

#### 1. AnswerWidget (`answer_widget.dart`)

**Added `_hasBeenRevealed` flag** to track revealed state persistently:
- Flag is set when revealed state is applied (via `_jumpToRevealedValue` or `_revealToValue`)
- Flag persists across rebuilds to prevent state loss
- Flag is cleared only when `_resetVisualState` is called (and only if revealed props are not available)

**Simplified `didUpdateWidget` logic** with clear priority order:
1. **Priority 1**: Handle revealed state (highest priority)
   - If controller is null: apply revealed state immediately (prop-controlled mode)
   - If controller is bound and widget already revealed: preserve state
   - If controller is bound and widget not yet revealed: let controller animate first
2. **Priority 2**: Reset if revealed props were explicitly removed
3. **Priority 3**: Controller manages state when bound (but don't override revealed state)
4. **Priority 4**: Sync to value prop (prop-controlled mode, non-revealed)

**Key improvements**:
- Removed `controller == null` requirement from `hasRevealedProps` check (allows revealed props to work with controller bound for last question)
- When controller unbinds, preserve revealed state if question is revealed (via props or flag)
- `_resetVisualState` checks for revealed props before resetting
- Revealed state persists across rebuilds via `_hasBeenRevealed` flag

#### 2. Question Screen (`question_screen_v2.dart`)

**Simplified prop-passing logic**:
- Always pass `revealedAnswer` and `revealedColor` when `showFeedback == true`
- Removed complex conditional logic - let widget decide how to use props

#### 3. Controller (`question_screen_v2_controller.dart`)

**Clear animation state on review mode entry**:
- Added logic to clear `_animatingQuestionIndex` and `_animationProgress` when entering review mode
- Prevents stale animation state from affecting revealed questions

### What's Working

✅ **Color preservation**: Leaving cards and review mode cards (except last) now retain their score-based colors
✅ **Last card in review mode**: Correctly maintains both value and color
✅ **Unit tests**: All existing tests continue to pass
✅ **No regressions**: Answer leakage prevention still works

### What's Still Broken

❌ **Leaving card values**: Color is preserved but values reset to default (number=1, empty OM, default unit)
❌ **Review mode values**: All cards except last reset to default values
❌ **Review mode colors**: All cards except last reset colors (despite color preservation working for leaving cards)
❌ **Final card animation**: Sometimes doesn't animate (intermittent issue)

### Root Cause Analysis

The current implementation preserves the **visual state** (color) but not the **controller state** (values). When `_jumpToRevealedValue` is called, it:
1. Sets `_digitsOverrideColor` ✅ (preserved)
2. Calls `_digitsController.jumpTo()`, `_omController.jumpTo()`, `_unitController.jumpTo()` ❌ (not preserved across rebuilds)

The sub-controllers (`_digitsController`, `_omController`, `_unitController`) are being reset or not synced correctly when:
- Controller unbinds and revealed props are applied
- Review mode activates and widgets rebuild
- Multiple rebuild cycles occur in quick succession

### Next Steps for Next Agent

1. **Investigate controller state preservation**:
   - Why are `_digitsController`, `_omController`, `_unitController` values not persisting?
   - Check if `_syncControllersToValue` is being called incorrectly
   - Verify that `_jumpToRevealedValue` is actually setting controller values correctly
   - Consider syncing controllers in `build()` method if revealed (as fallback)

2. **Review mode issue**:
   - Why does the last card work but others don't?
   - Check if revealed props are being passed correctly for all cards in review mode
   - Verify `_hasBeenRevealed` flag is being set correctly for all cards
   - Check if `initState` vs `didUpdateWidget` behavior differs for last card

3. **Final card animation**:
   - Why is it intermittent?
   - Check timing between controller binding and reveal event
   - Verify post-frame callbacks are executing correctly
   - Check if `_hasBeenRevealed` flag is being set too early, preventing animation

4. **Debugging approach**:
   - Add logging to `_jumpToRevealedValue` to verify it's being called with correct values
   - Add logging to `_syncControllersToValue` to see when/why it's being called
   - Check if `_hasBeenRevealed` flag is being cleared incorrectly
   - Verify revealed props are available when controller unbinds
   - Add logging to controller's `jumpTo` methods to see if they're being called

5. **Potential fixes to try**:
   - Ensure `_jumpToRevealedValue` is called on every rebuild when revealed props are available (not just once)
   - Check if `_syncControllersToValue` needs to be guarded differently
   - Consider syncing controllers in `build()` method if revealed (as fallback)
   - Verify that `_hasBeenRevealed` flag check in `_syncControllersToValue` is working correctly
   - Check if controllers need to be re-initialized in `initState` when revealed props are present

### Files Modified

- `apps/fermi-frontend/lib/widgets/answer_widget.dart` - Main fixes
- `apps/fermi-frontend/lib/screens/question_v2/question_screen_v2.dart` - Always pass revealed props
- `apps/fermi-frontend/lib/screens/question_v2/question_screen_v2_controller.dart` - Clear animation state on review mode

### Test Status

✅ All unit tests pass (`answer_leakage_test.dart`)
⚠️ Manual testing reveals remaining issues with value preservation

The next agent should focus on understanding why controller values (digits, OM, unit) are not persisting while visual state (color) is preserved. The issue appears to be in how the sub-controllers maintain their state across rebuilds.
