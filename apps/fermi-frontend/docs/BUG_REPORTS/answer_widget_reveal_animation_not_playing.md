# Bug Report: Answer Widget Reveal Animation Not Playing

## Status
**CLOSED** - Fixed by making animation methods properly async and ensuring all animations start together

## Date
Fixed: Current session
Original: After implementing explicit start/end value passing

## Executive Summary

When a question reveals, the answer widget should smoothly animate from the user's submitted answer to the correct revealed answer over 600ms. The widget was **jumping instantly** to the revealed answer without any animation. This has been fixed.

**Root Cause**: Animation methods in sub-controllers (`DigitWheelsController`, `OmLabelController`, `UnitTapeController`, `StringWheel`) were not properly awaiting the underlying `animateToItem()` calls, causing them to return immediately even though animations hadn't completed.

**Solution**: Made all animation methods properly async and await their underlying animations. Also ensured all visual changes (values, colors, tap indicators) start simultaneously.

**Current State**:
- ✅ **Value preservation**: Answer values are preserved correctly across navigation
- ✅ **Color preservation**: Score-based colors are preserved correctly
- ✅ **Final card display**: Final card shows correct answer
- ✅ **Architecture**: Explicit start/end values are passed to `reveal()` method
- ✅ **Reveal animation**: Answer widget animates smoothly over 600ms
- ✅ **Synchronized animations**: All components (digits, OM, unit) animate together
- ✅ **Synchronized colors**: All colors change simultaneously at animation start
- ✅ **Synchronized tap indicators**: All tap indicators fade together with matching durations

## Problem Description

### Issue: Missing Reveal Animation

**Scenario**: User submits an answer, question reveals, answer widget should animate from user's input to correct answer.

**Expected Behavior**:
- Answer widget smoothly animates digits, order of magnitude, and unit from submitted value to revealed answer
- Animation duration: 600ms (as specified in controller)
- Visual feedback shows the transition
- No visual jumps or snaps - single smooth motion from start to end

**Actual Behavior**:
- Answer widget jumps instantly to revealed answer
- No animation visible
- Values change immediately without transition
- Appears as if `jumpTo()` was called instead of `animateTo()`

**Reproduction Steps**:
1. Start a game and answer a question
2. Submit the answer (either manually or via auto-submit)
3. Wait for question to reveal (all players submit or deadline expires)
4. Observe: Answer widget jumps instantly to correct answer (no animation)

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
│   └── GameCarousel
│       └── GameCard (question + answer display)
│           ├── QuestionWidget (displays question text)
│           └── AnswerWidget (controlled component)
│               ├── DigitWheels (number input with animation)
│               ├── OmLabel (order of magnitude selector with animation)
│               └── UnitTape (unit selector with animation)
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
- Triggers reveal animations via `_triggerRevealAnimation()`

**Key Fields**:
```dart
Map<int, QuestionState> _questionStates;  // Per-question state cache
Map<int, AnswerValue> _animationProgress;  // Animation progress tracking
int? _animatingQuestionIndex;              // Which question is animating
int _currentIndex;                         // Currently displayed question
bool _isReviewMode;                        // Whether in review mode
bool _reviewModePending;                  // Review mode pending until final animation completes
AnswerValue? _localSubmittedAnswer;       // User's submitted answer (ground truth)
AnswerController _answerController;        // Shared controller for current question
Timer? _reviewModeActivationTimer;        // Delays review mode activation
```

**Key Methods**:

**`getDisplayAnswer(int index)`** (lines 220-277):
Computes what value to display for a question with priority:
1. **Priority 1**: Animation progress (if actively animating) - `_animationProgress[index]`
2. **Priority 2**: Revealed answer (for revealed questions, ONLY if not animating)
3. **Priority 3**: User's current input (for current editable question)
4. **Priority 4**: Default fallback

**`_triggerRevealAnimation(int index, AnswerValue correctAnswer)`** (lines 891-955):
Consolidated method that triggers reveal animation:
1. Validates question is current and should animate
2. Uses `_localSubmittedAnswer` as ground truth for starting position (with fallbacks)
3. Sets `_animatingQuestionIndex = index`
4. Sets `_animationProgress[index] = startValue`
5. Calls `notifyListeners()` once
6. Uses post-frame callback to ensure widget is ready
7. Calls `_answerController.reveal(startValue, displayAnswer, ...)` with explicit start/end values
8. Updates `_animationProgress` during animation via `onProgress` callback
9. Clears animation state on completion
10. Schedules review mode activation for final question (1 second delay)

**`_scheduleReviewModeActivation()`** (lines 957-966):
Schedules review mode activation with 1-second delay after final animation completes.

#### 2. AnswerWidget
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
bool _isControllerAnimationPending;   // Whether controller animation is expected but hasn't started
bool _hasBeenRevealed;                // Track if widget has revealed state (persists across rebuilds)

final DigitWheelsController _digitsController;  // Sub-controller for digits
final OmLabelController _omController;          // Sub-controller for OM
final UnitTapeController _unitController;      // Sub-controller for unit
```

**Key Methods**:

**`didUpdateWidget()`** (lines 224-343):
Handles widget updates with priority system:
1. **Priority 1**: Handle revealed state (highest priority)
   - If controller is null: Apply immediately via `_jumpToRevealedValue()`
   - If controller is bound:
     - If animation pending/animating: Update color only, don't jump
     - If already revealed: Apply changes if props changed
     - **Otherwise**: Set `_isControllerAnimationPending = true` and return
2. **Priority 2**: Reset if revealed props removed
3. **Priority 3**: Controller manages state when bound
4. **Priority 4**: Sync to value prop (prop-controlled mode) - **BUT** only if not pending/animating

**`_revealToValue()`** (lines 407-470):
Animation method called by controller:
1. Sets `_isControllerAnimating = true` and clears pending flag
2. **Jumps controllers to explicit start value** (eliminates ambiguity)
3. **Sets colors and revealed state BEFORE starting animations** (ensures all visual changes start together)
4. **Animates all components in parallel** via `Future.wait()`:
   - Digits via `_digitsController.revealTo()`
   - OM via `_omController.animateTo()`
   - Unit via `_unitController.animateTo()`
5. Updates state on completion

**Key Fix**: All animations now run in parallel using `Future.wait()`, and colors/tap indicators are set before animations start to ensure synchronization.

**`_syncControllersToValue()`** (lines 347-366):
Syncs sub-controllers to current value:
- If revealed: Syncs to `_revealedValue`
- Otherwise: Syncs to `widget.value`
- Uses `jumpTo()` which instantly sets values

**`_jumpToRevealedValue()`** (lines 368-409):
Instantly jumps to revealed state without animation:
- Stores `_revealedValue`
- Sets `_hasBeenRevealed = true`
- Calls `jumpTo()` on all sub-controllers
- Sets color

#### 3. AnswerController
**File**: `apps/fermi-frontend/lib/widgets/answer_widget.dart` (lines 10-99)

Shared controller that allows external code (the screen controller) to:
- Read current value
- Jump to a value instantly
- Animate to a value
- Reveal answer with animation and color
- Reset visual state

**Key Methods**:
- `reveal(start, target, duration, color, {onProgress, onComplete})` - Animates to revealed state with explicit start/end values
- `jumpTo(target)` - Jumps to value instantly
- `resetVisualState()` - Clears revealed colors

The `reveal()` method calls the widget's `_revealToValue()` method which was bound during `initState()`.

#### 4. Sub-Controllers

**DigitWheelsController** (`apps/fermi-frontend/lib/widgets/digit_wheels.dart`):
- `revealTo(number, duration)` - Animates digits to target number
- `jumpTo(number)` - Instantly sets number
- `animateTo(number, duration)` - Animates to number

**OmLabelController** (`apps/fermi-frontend/lib/widgets/om_label.dart`):
- `animateTo(om, duration)` - Animates to order of magnitude
- `jumpTo(om)` - Instantly sets OM

**UnitTapeController** (`apps/fermi-frontend/lib/widgets/unit_tape.dart`):
- `animateTo(unit, duration)` - Animates to unit
- `jumpTo(unit)` - Instantly sets unit

### Data Flow: Question Reveal

**Current Flow (Broken)**:

1. **Backend Event**: Game server sends reveal event (`_handleReveal()` or `_handlePlayersAnswers()`)
2. **Controller**: Handler is called
   - Sets `QuestionState.isRevealed = true`
   - Sets `QuestionState.correctAnswer`
   - Calls `_triggerRevealAnimation(index, correctAnswer)`
3. **Controller State Update**: `_triggerRevealAnimation()`:
   - Computes `startValue` from `_localSubmittedAnswer ?? state.userAnswer ?? default`
   - Computes `displayAnswer` from `correctAnswer` via `_toDisplayAnswer()`
   - Sets `_animatingQuestionIndex = index`
   - Sets `_animationProgress[index] = startValue`
   - Calls `notifyListeners()` **once**
4. **Screen Build**: `_buildGameCard()` for current question
   - Computes `displayAnswer = _controller.getDisplayAnswer(index)`
   - **Should return**: `_animationProgress[index]` (startValue) because `_animatingQuestionIndex == index`
   - Passes `revealedAnswer` and `revealedColor` props
   - Binds `answerController` for current question
5. **Widget Rebuild**: `AnswerWidget.didUpdateWidget()` is called
   - Sees `hasRevealedProps == true` and `controller != null`
   - Sets `_isControllerAnimationPending = true` (line 314)
   - Returns early (doesn't sync controllers)
6. **Controller Post-Frame**: `_triggerRevealAnimation` post-frame callback executes
   - Verifies conditions still valid
   - Calls `_answerController.reveal(startValue, displayAnswer, 600ms, color, ...)`
7. **Widget Animation**: `_revealToValue()` is called
   - Sets `_isControllerAnimating = true`
   - **Jumps controllers to start value** (line 424-428)
   - **Should animate** from start to target
   - **PROBLEM**: Animation doesn't play - values jump instantly instead

## Root Cause Analysis

The root cause is **unknown** but the symptoms suggest:

1. **Sub-controllers might skip animation**: The sub-controllers (`DigitWheelsController.revealTo()`, `OmLabelController.animateTo()`, `UnitTapeController.animateTo()`) might have logic that skips animation if already at target value, or if start equals target.

2. **Controllers might be at target before animation starts**: Despite jumping controllers to start value in `_revealToValue()`, something might be syncing them to target value before animation begins.

3. **Timing issue**: There might be a race condition where controllers get synced to revealed value AFTER we set the pending flag but BEFORE the post-frame callback runs.

4. **Widget rebuilds**: Multiple rebuilds might occur between setting animation state and post-frame callback executing, causing controllers to sync to wrong values.

5. **Sub-controller implementation**: The sub-controllers might check `currentValue == targetValue` and skip animation if they match.

## Recent Changes Made

The following changes were implemented to fix the animation issue, but the problem persists:

1. **Explicit Start/End Values**: Modified `AnswerController.reveal()` to accept explicit `start` and `target` values instead of inferring start from widget state.

2. **Ground Truth for Start Value**: Updated `_triggerRevealAnimation()` to use `_localSubmittedAnswer` as ground truth for starting position (with fallbacks to `state.userAnswer` and default).

3. **Simplified Widget Logic**: Removed `_animationStartValue` field and complex controller syncing logic from `didUpdateWidget()` Priority 1 path.

4. **Priority 4 Guard**: Added `!_isControllerAnimationPending` check to Priority 4 to prevent syncing controllers when animation is pending.

5. **Review Mode Delay**: Implemented 1-second delay before review mode activation after final animation completes.

6. **Reduced Rebuilds**: Removed redundant `notifyListeners()` calls from `_handleReveal()` and `_handlePlayersAnswers()`.

## Code References

### Key Files

1. **`apps/fermi-frontend/lib/screens/question_v2/question_screen_v2_controller.dart`**
   - Lines 220-277: `getDisplayAnswer()` method
   - Lines 891-955: `_triggerRevealAnimation()` method
   - Lines 957-966: `_scheduleReviewModeActivation()` method
   - Lines 968-994: `_handleReveal()` method
   - Lines 1172-1312: `_handlePlayersAnswers()` method

2. **`apps/fermi-frontend/lib/widgets/answer_widget.dart`**
   - Lines 10-99: `AnswerController` class
   - Lines 224-343: `didUpdateWidget()` logic
   - Lines 347-366: `_syncControllersToValue()` method
   - Lines 368-409: `_jumpToRevealedValue()` method
   - Lines 394-470: `_revealToValue()` animation method

3. **`apps/fermi-frontend/lib/screens/question_v2/question_screen_v2.dart`**
   - Lines 385-491: `_buildGameCard()` method
   - Lines 394-395: `getDisplayAnswer()` call
   - Lines 397-401: Revealed props passing
   - Lines 457-460: Controller binding logic

### Related Files

- `apps/fermi-frontend/lib/widgets/digit_wheels.dart` - DigitWheelsController implementation
- `apps/fermi-frontend/lib/widgets/om_label.dart` - OmLabelController implementation
- `apps/fermi-frontend/lib/widgets/unit_tape.dart` - UnitTapeController implementation

## Investigation Needed

To diagnose this issue, investigate:

1. **Sub-Controller Behavior**: Check if `DigitWheelsController.revealTo()`, `OmLabelController.animateTo()`, and `UnitTapeController.animateTo()` skip animation when already at target value. Look for early returns or conditional logic that checks `currentValue == targetValue`.

2. **Controller State**: Add logging to track:
   - When `_revealToValue()` is called and what start/target values are
   - What the current controller values are when animation starts
   - Whether sub-controller animation methods are actually called
   - Whether sub-controllers skip animation and why

3. **Widget Rebuilds**: Track:
   - How many times `didUpdateWidget()` is called during reveal
   - What `widget.value` is at each rebuild
   - Whether controllers are synced between setting pending flag and post-frame callback

4. **Timing**: Verify:
   - Whether `startValue` equals `displayAnswer` (would cause instant jump)
   - Whether controllers are at target value before `_revealToValue()` is called
   - Whether multiple rebuilds occur between animation setup and execution

5. **Sub-Controller Implementation**: Examine:
   - `apps/fermi-frontend/lib/widgets/digit_wheels.dart` - `_revealTo()` and `_animateTo()` methods
   - `apps/fermi-frontend/lib/widgets/om_label.dart` - `animateTo()` implementation
   - `apps/fermi-frontend/lib/widgets/unit_tape.dart` - `animateTo()` implementation
   - Look for logic that might skip animation

## Success Criteria

1. ✅ Answer widget animates smoothly from user input to revealed answer
2. ✅ Animation duration is ~600ms as specified
3. ✅ All components animate (digits, OM, unit)
4. ✅ Final question animates correctly before review mode activates
5. ✅ No regressions in value/color preservation
6. ✅ No regressions in review mode behavior
7. ✅ No visual jumps or snaps - single smooth motion

## Environment

- **Framework**: Flutter 3.24.2
- **Platform**: Android (tested), iOS (likely affected)
- **Architecture**: MVVM with ChangeNotifier
- **State Management**: Provider pattern with ChangeNotifier

## Related Documentation

- `apps/fermi-frontend/docs/BUG_REPORTS/answer_widget_reveal_animation_missing.md` - Previous bug report (outdated, code has changed)
- `apps/fermi-frontend/docs/ARCHITECTURE.md` - Overall architecture documentation
- `apps/fermi-frontend/docs/TESTS.md` - Testing guidelines

## Debug Prints Added

Comprehensive debug prints have been added throughout the reveal animation flow to help diagnose the issue. All debug messages are prefixed with `[DEBUG]` for easy filtering.

### Controller Layer (`question_screen_v2_controller.dart`)

1. **`_handleReveal()`** (line ~1014):
   - Entry point when reveal event is received
   - Logs: index, correct answer, currentIndex, wasRevealed
   - Logs: Whether animation is triggered or skipped

2. **`_handlePlayersAnswers()`** (line ~1343):
   - Entry point when players answers snapshot is received
   - Logs: Whether animation is triggered or skipped with reasons

3. **`_triggerRevealAnimation()`** (line ~897):
   - Main animation trigger method
   - Logs: Entry conditions (index, currentIndex, isReviewMode, reviewModePending)
   - Logs: Abort reasons if animation is skipped
   - Logs: startValue, displayAnswer, correctAnswer, _localSubmittedAnswer, state.userAnswer
   - Logs: Animation state setup (_animatingQuestionIndex, _animationProgress)
   - Logs: Post-frame callback execution and conditions check
   - Logs: reveal() call with all parameters
   - Logs: onProgress callbacks during animation
   - Logs: onComplete callback when animation finishes

4. **`getDisplayAnswer()`** (line ~220):
   - Called frequently to determine what value to display
   - Logs: Which priority path is taken (1-4) and the returned value
   - Helps track value changes during animation

### Widget Layer (`answer_widget.dart`)

5. **`AnswerController.reveal()`** (line ~70):
   - Entry point for reveal animation from controller
   - Logs: All parameters (start, target, duration, color)
   - Logs: Whether _reveal function is bound or null

6. **`AnswerWidget.didUpdateWidget()`** (line ~220):
   - Called on every widget rebuild
   - Logs: Current widget props (value, revealedAnswer, revealedColor, controller, editable)
   - Logs: Internal state (_isControllerAnimating, _isControllerAnimationPending, _hasBeenRevealed)
   - Logs: hasRevealedProps and hadRevealedProps flags
   - Logs: Which priority path is taken in the update logic

7. **`AnswerWidget._revealToValue()`** (line ~402):
   - Actual animation execution method
   - Logs: Start with all parameters and current controller values
   - Logs: After jumping controllers to start value
   - Logs: Before/after each sub-controller animation (digits, OM, unit)
   - Logs: Final state setting and completion

### Sub-Controller Layer

8. **`DigitWheelsController._revealTo()`** (`digit_wheels.dart`, line ~305):
   - Logs: Target value, duration, current value
   - Logs: Before/after calling _animateTo()

9. **`DigitWheelsController._animateTo()`** (`digit_wheels.dart`, line ~293):
   - Logs: Target value, clamped value, current value, decomposed digits
   - Logs: Before/after calling animateToItem on all wheels

10. **`OmLabelController.animateTo()`** (`om_label.dart`, line ~122, ~374):
    - Logs: Target value, duration, current value
    - Logs: Before/after calling _wheel.animateTo()

11. **`UnitTapeController.animateTo()`** (`unit_tape.dart`, line ~134):
    - Logs: Target value, duration, current value
    - Logs: Before/after calling _wheel.animateTo()

12. **`StringWheel._animateTo()`** (`string_wheel.dart`, line ~117):
    - Logs: Target value, target index, current index, duration
    - Logs: Before/after calling animateToItem()
    - Logs: Abort if values list is empty

### Screen Layer (`question_screen_v2.dart`)

13. **`_buildGameCard()`** (line ~403):
    - Called when building each game card
    - Logs: isCurrentQuestion, showFeedback, displayAnswer, revealedAnswer, revealedColor
    - Helps track what props are passed to AnswerWidget

### Expected Debug Flow

When a reveal animation should occur, you should see this sequence:

1. `[DEBUG] _handleReveal` or `[DEBUG] _handlePlayersAnswers` - Event received
2. `[DEBUG] _triggerRevealAnimation START` - Animation triggered
3. `[DEBUG] _triggerRevealAnimation: startValue=...` - Start/end values computed
4. `[DEBUG] getDisplayAnswer[...]: Priority 1` - Widget rebuild with animation progress
5. `[DEBUG] _buildGameCard[...]` - Card rebuild with new props
6. `[DEBUG] AnswerWidget.didUpdateWidget` - Widget update with revealed props
7. `[DEBUG] _triggerRevealAnimation POST-FRAME` - Post-frame callback executes
8. `[DEBUG] AnswerController.reveal` - Controller method called
9. `[DEBUG] AnswerWidget._revealToValue START` - Animation begins
10. `[DEBUG] DigitWheels._revealTo` - Digits animation starts
11. `[DEBUG] DigitWheels._animateTo` - Digits animation details
12. `[DEBUG] StringWheel._animateTo` - String wheel animation (for OM/unit)
13. `[DEBUG] AnswerWidget._revealToValue: COMPLETE` - Animation finished
14. `[DEBUG] _triggerRevealAnimation ON-COMPLETE` - Completion callback

### How to Use

1. Run the app on emulator
2. Start recording terminal output from when you hit "Next"
3. Submit an answer and wait for reveal
4. Filter terminal output for `[DEBUG]` to see the flow
5. Look for:
   - Missing steps in the sequence
   - Unexpected abort messages
   - Values that don't match expectations
   - Animation methods that return immediately without animating
   - Controllers that are already at target value before animation starts

---

## Resolution

**Fixed**: All animation methods now properly await their underlying animations:
- `DigitWheelsController._animateTo()` and `_revealTo()` are async and await wheel animations
- `StringWheel._animateTo()` is async and awaits `animateToItem()`
- `OmLabelController` and `UnitTapeController` bindings are async and await wheel animations
- All animations run in parallel using `Future.wait()` for synchronized execution
- Colors and tap indicator fades start before value animations to ensure all visual changes are synchronized
- Tap indicator fade durations match value animation durations (600ms)

**Files Changed**:
- `apps/fermi-frontend/lib/widgets/digit_wheels.dart` - Made `_animateTo()` and `_revealTo()` async
- `apps/fermi-frontend/lib/widgets/string_wheel.dart` - Made `_animateTo()` async
- `apps/fermi-frontend/lib/widgets/om_label.dart` - Made bindings async, added duration parameter to `setRevealed()`
- `apps/fermi-frontend/lib/widgets/unit_tape.dart` - Made bindings async, added duration parameter to `setRevealed()`
- `apps/fermi-frontend/lib/widgets/answer_widget.dart` - Run all animations in parallel, set colors/indicators before animations start

**Last Updated**: Current session (bug fixed)
**Status**: CLOSED - Animation now works correctly, all components animate together smoothly
**Priority**: High - Core UX feature (now working)
