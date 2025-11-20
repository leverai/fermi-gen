# Bug Report: Answer Widget Revealed State Preservation

## Status
**MOSTLY RESOLVED** - Value and color preservation working ✅, animation issues remain ⚠️

## Date
Current session (following fix implementation)

## Executive Summary

Answer widgets in a Flutter carousel game app fail to preserve their **revealed state** (correct answer values and score-based colors) when navigating between questions or entering review mode.

**Current State** (After Fix):
- ✅ **Value preservation**: Answer values (number, order of magnitude, unit) are now preserved correctly
- ✅ **Color preservation**: Score-based colors are preserved correctly
- ⚠️ **Final card color animation**: Sometimes doesn't animate to correct score-based color (intermittent)
- ⚠️ **Answer animation**: Answer widget jumps instantly instead of animating to revealed answer

## Problem Description

### Issue 1: Leaving Card Values Reset (FIXED ✅)
**Scenario**: User submits answer, question reveals with animation, then presses "Next" to move to next question.

**Expected**: Leaving card maintains revealed answer values and color
**Actual**:
- ✅ Color is preserved correctly
- ✅ Values are preserved correctly

**Status**: **RESOLVED** - Values are now stored in widget state and persist across rebuilds

### Issue 2: Review Mode Reset (FIXED ✅)
**Scenario**: Game completes, enters review mode where users can swipe through all questions.

**Expected**: All revealed questions display their correct answers with score-based colors
**Actual**:
- ✅ All cards maintain both value and color correctly

**Status**: **RESOLVED** - Values are now stored in widget state and persist in review mode

### Issue 3: Final Card Color Animation (INTERMITTENT ⚠️)
**Scenario**: Last question reveals, sometimes doesn't animate to correct score-based color.

**Expected**: Final card always animates to correct score-based color
**Actual**: Color sometimes doesn't update to score-based color (intermittent)

**Status**: **PARTIALLY RESOLVED** - Color is preserved but animation to score-based color sometimes fails

### Issue 4: Answer Animation Missing (NEW ⚠️)
**Scenario**: Question reveals, answer widget should animate to correct answer.

**Expected**: Answer widget animates smoothly to revealed answer
**Actual**: Answer widget jumps instantly to revealed answer (no animation)

**Status**: **BROKEN** - Animation is not playing, values jump instantly instead

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
```dart
Map<int, QuestionState> _questionStates;  // Per-question state cache
Map<int, AnswerValue> _animationProgress;  // Animation progress tracking
int? _animatingQuestionIndex;              // Which question is animating
int _currentIndex;                         // Currently displayed question
bool _isReviewMode;                        // Whether in review mode
AnswerController _answerController;        // Shared controller for current question
```

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
```dart
class QuestionState {
  final String questionText;
  final List<String> units;
  final AnswerValue? correctAnswer;      // The correct answer (set when revealed)
  final AnswerValue? userAnswer;        // User's current input for this question
  final Map<String, AnswerValue> submittedAnswers;  // Per-player submitted answers
  final Map<String, double> scores;     // Per-player scores
  final bool isRevealed;                // Whether this question has been revealed
  // ... other metadata
}
```

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
```dart
final AnswerValue value;              // Current display value (always required)
final AnswerController? controller;   // Binds widget to controller for animations
final AnswerValue? revealedAnswer;    // If provided, shows this as the revealed answer
final Color? revealedColor;           // Score-based color to display for revealed state
final bool editable;                  // Whether user can edit
```

**Key Internal State**:
```dart
Color? _digitsOverrideColor;          // Color to display for revealed state
AnswerValue? _revealedValue;          // Store revealed answer in widget state (persists across rebuilds)
bool _isRevealing;                    // Whether currently revealing
bool _isControllerAnimating;          // Whether controller is animating
bool _hasBeenRevealed;                // Track if widget has revealed state (persists across rebuilds)

final DigitWheelsController _digitsController;  // Sub-controller for digits
final OmLabelController _omController;          // Sub-controller for OM
final UnitTapeController _unitController;      // Sub-controller for unit
```

**Key Methods**:
- `didUpdateWidget()`: Syncs internal state when props change
- `_jumpToRevealedValue()`: Jumps to revealed state without animation, stores value in widget state
- `_revealToValue()`: Animates to revealed state, stores value when animation completes
- `_syncControllersToValue()`: Syncs sub-controllers to stored revealed value or `value` prop
- `_resetVisualState()`: Resets colors, revealed value, and revealed flags

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
   - Sets `_hasBeenRevealed = true` when animation completes
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
   - Always passes `revealedAnswer` and `revealedColor` when `showFeedback == true`
   - For current question: binds `answerController`
   - For non-current questions: `answerController = null`
5. **Widget Rebuild**: `AnswerWidget.didUpdateWidget()` is called
   - Detects controller unbinding (old controller bound, new is null)
   - Preserves revealed state using stored `_revealedValue` ✅

### Data Flow: Review Mode Entry

1. **Backend**: Game state changes to `GameState.gameFinished`
2. **Controller**: `_isReviewMode = true`
   - Clears `_animationProgress` and `_animatingQuestionIndex`
3. **Screen Build**: All questions built with `answerController = null` (except last question)
4. **Widget Rebuild**: All widgets show revealed state using stored `_revealedValue` ✅

## Current Implementation

### Changes Made (Final Fix - Solution 4: Store Values in Widget State)

#### 1. AnswerWidget (`answer_widget.dart`)

**Added `_revealedValue` field** (Solution 4):
```dart
AnswerValue? _revealedValue;  // Store revealed answer in widget state (like _digitsOverrideColor)
```

- Stores revealed answer values directly in widget state (mirrors `_digitsOverrideColor` pattern)
- Provides persistent storage that survives rebuilds, independent of props or controller state
- Single source of truth for revealed values

**Added effective value getters**:
```dart
int get _effectiveNumber => (_revealedValue?.number ?? widget.value.number).clamp(1, _numbersPerOm);
String get _effectiveOm => _revealedValue?.orderOfMagnitude ?? widget.value.orderOfMagnitude;
String get _effectiveUnit => _revealedValue?.unit ?? widget.value.unit;
```

- Computed properties that prioritize revealed values over widget.value
- Available for future use if needed

**Updated `_jumpToRevealedValue` method**:

```dart
@override
void didUpdateWidget(covariant AnswerWidget oldWidget) {
  super.didUpdateWidget(oldWidget);

  // Check if revealed props are available (regardless of controller binding)
  final bool hasRevealedProps = widget.revealedAnswer != null &&
      widget.revealedColor != null &&
      !widget.editable;

  // Handle controller binding changes
  if (oldWidget.controller != widget.controller) {
    final bool controllerUnbound =
        oldWidget.controller != null && widget.controller == null;

    if (controllerUnbound) {
      // Stop any ongoing animation when controller unbinds
      _isRevealing = false;
      _isControllerAnimating = false;

      // If question is revealed (via props or flag), preserve revealed state
      if (hasRevealedProps || _hasBeenRevealed) {
        if (hasRevealedProps) {
          _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
        }
        return;  // Preserve state even if props not available yet
      } else {
        _resetVisualState();
        _syncControllersToValue();
      }
    }
    // ... bind/rebind controller
  }

  // Priority 1: Handle revealed state (highest priority)
  if (hasRevealedProps) {
    if (widget.controller == null) {
      // Prop-controlled mode: apply immediately
      if (!_hasBeenRevealed || /* props changed */) {
        _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
      }
      return;
    }
    // Controller bound: let controller animate first, then preserve
    if (_hasBeenRevealed) {
      return;  // Already revealed, preserve state
    }
    // Controller will animate, don't jump immediately
  }

  // Priority 2: Reset if revealed props were explicitly removed
  // Priority 3: Controller manages state when bound
  // Priority 4: Sync to value prop (prop-controlled mode)
}
```

**Key improvements**:
- **Store values in widget state**: `_revealedValue` provides persistent storage (mirrors `_digitsOverrideColor` pattern)
- **Single source of truth**: Values persist independently of props or controller state
- **Controller re-syncing**: `_syncControllersToValue` ensures controllers match stored revealed value
- **Safety checks**: Post-frame callback in `build` ensures controllers stay synced
- **Simplified logic**: `didUpdateWidget` uses stored `_revealedValue` for comparisons

**`_jumpToRevealedValue` method**:
```dart
void _jumpToRevealedValue(AnswerValue target, Color color) {
  // Validate inputs
  if (target.number < 1 || target.number > _numbersPerOm) return;

  // Store revealed value in widget state FIRST
  _revealedValue = target;
  // Mark as revealed BEFORE setState to prevent race conditions
  _hasBeenRevealed = true;

  // Sync controllers to revealed value
  _digitsController.jumpTo(target.number.clamp(1, _numbersPerOm));
  _digitsController.setRevealEnabled(true);
  _omController.jumpTo(target.orderOfMagnitude);
  _omController.setRevealed(true);
  if (target.unit.isNotEmpty) {
    _unitController.jumpTo(target.unit);
    _unitController.setRevealed(true);
  }

  // Set visual state
  setState(() {
    _digitsOverrideColor = color;
  });
}
```

**Updated `_revealToValue` method** (animation):
```dart
setState(() {
  _digitsOverrideColor = color;
  _isRevealing = false;
  _isControllerAnimating = false;
  _hasBeenRevealed = true;
  _revealedValue = target; // Store revealed value in widget state
});
```

**`_syncControllersToValue` method**:
```dart
void _syncControllersToValue() {
  // Don't sync if widget has been revealed (revealed state takes priority)
  if (_hasBeenRevealed) {
    // When revealed, ensure controllers match stored revealed value
    if (_revealedValue != null) {
      _digitsController.jumpTo(_revealedValue!.number.clamp(1, _numbersPerOm));
      _omController.jumpTo(_revealedValue!.orderOfMagnitude);
      if (_revealedValue!.unit.isNotEmpty) {
        _unitController.jumpTo(_revealedValue!.unit);
      }
    }
    return;
  }

  // For non-revealed state, sync from widget.value
  _digitsController.jumpTo(_currentNumber);
  _omController.jumpTo(_currentOm);
  if (_currentUnit.isNotEmpty) {
    _unitController.jumpTo(_currentUnit);
  }
}
```

**Key improvement**: When revealed, controllers are synced from stored `_revealedValue` instead of being skipped. This ensures controllers maintain correct state even if they lose it between rebuilds.

**`_resetVisualState` method**:
```dart
void _resetVisualState() {
  // Don't reset if revealed props are available - preserve revealed state
  if (widget.revealedAnswer != null &&
      widget.revealedColor != null &&
      !widget.editable) {
    return;
  }

  setState(() {
    _digitsOverrideColor = null;
    _revealedValue = null; // Clear revealed value
    _isRevealing = false;
    _isControllerAnimating = false;
    _hasBeenRevealed = false;
    _digitsController.setRevealEnabled(false);
    _omController.setRevealed(false);
    _unitController.setRevealed(false);
  });
}
```

**Updated `didUpdateWidget` logic**:
```dart
// Priority 1: Handle revealed state (highest priority)
if (hasRevealedProps) {
  if (widget.controller == null) {
    // Prop-controlled mode: Always apply to ensure consistency
    // Check if we need to update (props changed or not yet revealed)
    if (!_hasBeenRevealed ||
        _revealedValue != widget.revealedAnswer ||
        _digitsOverrideColor != widget.revealedColor) {
      _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
    }
    return;
  }

  // Controller is bound - if already revealed, ensure state is preserved
  if (_hasBeenRevealed && _revealedValue != null) {
    // Check if props changed
    if (_revealedValue != widget.revealedAnswer ||
        _digitsOverrideColor != widget.revealedColor) {
      _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
    }
    return;
  }
  // Controller will animate, wait for that
}
```

**Added safety check in `build` method**:
```dart
@override
Widget build(BuildContext context) {
  // If revealed, ensure controllers are synced (safety check)
  if (_hasBeenRevealed && _revealedValue != null && !_isRevealing) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hasBeenRevealed && _revealedValue != null) {
        // Re-sync controllers if they somehow got out of sync
        _syncControllersToValue();
      }
    });
  }
  // ... rest of build
}
```

#### 2. Question Screen (`question_screen_v2.dart`)

**Simplified prop-passing logic** (lines 397-401):
```dart
// Always pass revealed props when question is revealed - let widget decide how to use them
final revealedAnswer =
    showFeedback ? _controller.getRevealedAnswer(index) : null;
final revealedColor =
    showFeedback ? _controller.getRevealedColor(index) : null;
```

**Controller binding logic** (lines 457-460):
```dart
// In review mode, don't bind controller - use prop-based reveal instead
// EXCEPTION: For last question, allow controller binding even in review mode
// to enable animation when review mode activates simultaneously
answerController: (isCurrentQuestion &&
        (!_controller.isReviewMode || index == widget.questionCount - 1))
    ? _controller.answerController
    : null,
```

#### 3. Controller (`question_screen_v2_controller.dart`)

**Clear animation state on review mode entry** (lines 374-383):
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

### What's Working

✅ **Value preservation**: Leaving cards and review mode cards now retain their revealed answer values
✅ **Color preservation**: Leaving cards and review mode cards retain their score-based colors
✅ **State persistence**: Values stored in widget state (`_revealedValue`) persist across rebuilds
✅ **Controller syncing**: Controllers are re-synced from stored revealed value when needed
✅ **Unit tests**: All existing tests continue to pass (`answer_leakage_test.dart`)
✅ **No regressions**: Answer leakage prevention still works

### What's Still Broken

⚠️ **Final card color animation**: Sometimes doesn't animate to correct score-based color (intermittent)
⚠️ **Answer animation missing**: Answer widget jumps instantly to revealed answer instead of animating smoothly

## Root Cause Analysis

### The Core Problem (RESOLVED ✅)

**Original Issue**: The implementation preserved the **visual state** (color via `_digitsOverrideColor`) but not the **controller state** (values via sub-controllers).

**Root Cause**: Values were stored only in sub-controllers (`_digitsController`, `_omController`, `_unitController`), which don't maintain state reliably across rebuilds. Color worked because it was stored directly in widget state.

**Solution Applied**: Store revealed values directly in widget state (`_revealedValue`), mirroring the successful `_digitsOverrideColor` pattern. This provides persistent storage independent of controller state or prop changes.

### Why Values Now Persist

1. **Widget state storage**: `_revealedValue` is stored in widget state, persists across rebuilds ✅
2. **Controller re-syncing**: `_syncControllersToValue` ensures controllers match stored revealed value when revealed
3. **Safety checks**: Post-frame callback in `build` ensures controllers stay synced
4. **Independent of props**: Values persist even if props aren't passed every rebuild

### Remaining Issues

#### Issue 1: Final Card Color Animation (Intermittent)

**Problem**: Final card sometimes doesn't animate to correct score-based color.

**Possible Causes**:
- Race condition: Score-based color arrives after animation starts
- Color prop not being passed correctly for final card
- Animation state cleared before color is applied

**Investigation Needed**: Check timing of score arrival vs animation start for final question.

#### Issue 2: Answer Animation Missing

**Problem**: Answer widget jumps instantly to revealed answer instead of animating.

**Possible Causes**:
- `_jumpToRevealedValue` is being called instead of `_revealToValue` when controller is bound
- Controller animation not being triggered
- Animation state not properly initialized

**Investigation Needed**: Check if controller-bound widgets are using `reveal()` method vs `jumpTo()`.

## Code References

### Key Files

1. **`apps/fermi-frontend/lib/widgets/answer_widget.dart`**
   - Lines 150-170: State fields including `_hasBeenRevealed` flag
   - Lines 202-305: `didUpdateWidget` logic
   - Lines 283-302: `_jumpToRevealedValue` method
   - Lines 307-316: `_syncControllersToValue` method
   - Lines 400-417: `_resetVisualState` method

2. **`apps/fermi-frontend/lib/screens/question_v2/question_screen_v2.dart`**
   - Lines 397-401: Prop-passing logic (always pass revealed props)
   - Lines 457-460: Controller binding logic (special case for last question)

3. **`apps/fermi-frontend/lib/screens/question_v2/question_screen_v2_controller.dart`**
   - Lines 374-383: Clear animation state on review mode entry
   - Lines 215-265: `getDisplayAnswer` method
   - Lines 1471-1477: `getRevealedAnswer` method
   - Lines 1462-1468: `getRevealedColor` method

4. **`apps/fermi-frontend/lib/screens/question_v2/widgets/carousel_page_wrapper.dart`**
   - Uses `AutomaticKeepAliveClientMixin` to keep widgets alive

### Related Files

- `apps/fermi-frontend/lib/widgets/digit_wheels.dart` - DigitWheelsController implementation
- `apps/fermi-frontend/lib/widgets/om_label.dart` - OmLabelController implementation
- `apps/fermi-frontend/lib/widgets/unit_tape.dart` - UnitTapeController implementation
- `apps/fermi-frontend/test/unit/controllers/question_screen_v2_controller_012B/answer_leakage_test.dart` - Unit tests

## Debugging Strategy

### 1. Add Comprehensive Logging

Add logging to understand the sequence of events:

```dart
// In _jumpToRevealedValue
print('[AnswerWidget] _jumpToRevealedValue called: target=$target, color=$color');
print('[AnswerWidget] Setting _hasBeenRevealed=true');
print('[AnswerWidget] Calling _digitsController.jumpTo(${target.number})');
print('[AnswerWidget] Calling _omController.jumpTo(${target.orderOfMagnitude})');
print('[AnswerWidget] Calling _unitController.jumpTo(${target.unit})');

// In _syncControllersToValue
print('[AnswerWidget] _syncControllersToValue called: _hasBeenRevealed=$_hasBeenRevealed');
if (_hasBeenRevealed) {
  print('[AnswerWidget] Skipping sync because _hasBeenRevealed=true');
}

// In didUpdateWidget
print('[AnswerWidget] didUpdateWidget: hasRevealedProps=$hasRevealedProps, _hasBeenRevealed=$_hasBeenRevealed');
print('[AnswerWidget] Controller: old=${oldWidget.controller != null}, new=${widget.controller != null}');
```

### 2. Check Controller State

Verify that controllers actually maintain state after `jumpTo()` calls:

```dart
// After calling jumpTo, check controller state
print('[AnswerWidget] After jumpTo - digitsController value: ${_digitsController.value}');
print('[AnswerWidget] After jumpTo - omController value: ${_omController.value}');
print('[AnswerWidget] After jumpTo - unitController value: ${_unitController.value}');
```

### 3. Investigate Rebuild Sequence

Log rebuild sequence to understand timing:

```dart
// In build method
print('[AnswerWidget] build called: value=${widget.value}, revealedAnswer=${widget.revealedAnswer}');
print('[AnswerWidget] _digitsOverrideColor=$_digitsOverrideColor');
print('[AnswerWidget] _hasBeenRevealed=$_hasBeenRevealed');
```

## Potential Solutions

### Solution 1: Re-sync Controllers on Every Rebuild When Revealed

If revealed, call `_jumpToRevealedValue` on every rebuild (not just once):

```dart
// In didUpdateWidget, Priority 1
if (hasRevealedProps) {
  if (widget.controller == null) {
    // Always re-apply revealed state (controllers might have reset)
    _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
    return;
  }
  // ...
}
```

**Pros**: Ensures controllers are always synced
**Cons**: Might cause flicker or unnecessary updates

### Solution 2: Sync Controllers in build() Method

As fallback, sync controllers in `build()` if revealed:

```dart
@override
Widget build(BuildContext context) {
  // If revealed and controller is null, ensure controllers are synced
  if (widget.revealedAnswer != null &&
      widget.revealedColor != null &&
      widget.controller == null &&
      !widget.editable &&
      _hasBeenRevealed) {
    // Sync controllers to revealed values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hasBeenRevealed) {
        _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
      }
    });
  }
  // ... rest of build
}
```

**Pros**: Ensures controllers are synced even if `didUpdateWidget` misses it
**Cons**: Post-frame callback might cause flicker

### Solution 3: Check Controller State Before Syncing

Verify controllers actually need syncing before skipping:

```dart
void _syncControllersToValue() {
  if (_hasBeenRevealed) {
    // Check if controllers actually have the correct values
    final currentValue = AnswerValue(
      number: _digitsController.value ?? _currentNumber,
      orderOfMagnitude: _omController.value ?? _currentOm,
      unit: _unitController.value ?? _currentUnit,
    );

    // Only skip if controllers already have revealed values
    if (widget.revealedAnswer != null && currentValue == widget.revealedAnswer) {
      return;
    }
  }
  // ... sync controllers
}
```

**Pros**: More intelligent syncing
**Cons**: Requires checking controller values (might not be exposed)

### Solution 4: Store Values in Widget State

Store revealed values in widget state, not just controllers:

```dart
class _AnswerWidgetState extends State<AnswerWidget> {
  // ... existing fields
  AnswerValue? _revealedValue;  // Store revealed value in widget state

  void _jumpToRevealedValue(AnswerValue target, Color color) {
    _hasBeenRevealed = true;
    _revealedValue = target;  // Store in widget state

    // Set controllers
    _digitsController.jumpTo(target.number.clamp(1, _numbersPerOm));
    // ...
  }

  // In build, use _revealedValue if available
}
```

**Pros**: Values persist in widget state like color does
**Cons**: Duplicates state (widget state + controller state)

### Solution 5: Initialize Controllers in initState When Revealed

If revealed props are present in `initState`, initialize controllers:

```dart
@override
void initState() {
  super.initState();

  // Initialize controllers with current value
  _digitsController.jumpTo(_currentNumber);
  // ...

  // If revealed answer is provided, jump directly to revealed state
  if (widget.revealedAnswer != null &&
      widget.revealedColor != null &&
      widget.controller == null &&
      !widget.editable) {
    _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
  }
}
```

**Pros**: Ensures controllers are initialized correctly
**Cons**: Only works if `initState` is called (not with keep-alive)

## Next Steps

1. **Add logging** to understand the exact sequence of events
2. **Check controller implementations** to see if they maintain state across rebuilds
3. **Test Solution 1** (re-sync on every rebuild) as simplest fix
4. **If Solution 1 doesn't work**, investigate why controllers don't maintain state
5. **Consider Solution 4** (store values in widget state) as most robust fix

## Success Criteria

### Primary Issues (RESOLVED ✅)

1. ✅ When a question reveals and user presses "Next", the leaving card maintains:
   - ✅ Score-based color
   - ✅ Correct answer values (number, order of magnitude, unit)

2. ✅ When entering review mode, all revealed questions display:
   - ✅ Their correct answers
   - ✅ Score-based colors
   - ✅ Not default/placeholder values

3. ✅ All existing unit tests continue to pass

4. ✅ No new bugs introduced (answer leakage, etc.)

### Remaining Issues (PARTIALLY RESOLVED ⚠️)

5. ⚠️ Final card color animation: Sometimes doesn't animate to correct score-based color (intermittent)
   - **Status**: Color is preserved but animation sometimes fails

6. ⚠️ Answer animation: Answer widget should animate smoothly to revealed answer
   - **Status**: Values are correct but animation is missing (jumps instantly)

## Related Documentation

- `BUG_REPORT_ANSWER_WIDGET_VALUE_LEAKAGE.md` - Previous bug and fix attempts
- `BUG_REPORT_CAROUSEL_STATE_FINAL.md` - Carousel state management fixes
- `BUG_REPORT_ANSWER_WIDGET_STATE.md` - Widget state management issues
- `apps/fermi-frontend/docs/ARCHITECTURE.md` - Overall architecture
- `apps/fermi-frontend/docs/TESTS.md` - Testing guidelines

## Environment

- **Framework**: Flutter 3.24.2
- **Platform**: Android (tested), iOS (likely affected)
- **Architecture**: MVVM with ChangeNotifier
- **State Management**: Provider pattern with ChangeNotifier

---

**Last Updated**: Current session
**Status**: Mostly resolved - values and colors preserved ✅, animation issues remain ⚠️
**Priority**: Medium - core functionality working, animation polish needed
