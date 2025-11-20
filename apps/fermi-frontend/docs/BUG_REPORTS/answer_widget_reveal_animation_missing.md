# Bug Report: Answer Widget Reveal Animation Missing

## Status
**OPEN** - Answer widget jumps instantly instead of animating to revealed answer

## Date
Current session (after fixing revealed state preservation and review mode race condition)

## Executive Summary

When a question reveals, the answer widget should smoothly animate from the user's current input to the correct revealed answer. However, the widget currently **jumps instantly** to the revealed answer without any animation. The final card now shows the correct answer (after fixing review mode race condition), but the animation itself is not playing.

**Current State**:
- ✅ **Value preservation**: Answer values are preserved correctly across navigation
- ✅ **Color preservation**: Score-based colors are preserved correctly
- ✅ **Final card display**: Final card now shows correct answer after review mode fix
- ❌ **Reveal animation**: Answer widget jumps instantly instead of animating smoothly

## Problem Description

### Issue: Missing Reveal Animation

**Scenario**: User submits an answer, question reveals, answer widget should animate from user's input to correct answer.

**Expected Behavior**:
- Answer widget smoothly animates digits, order of magnitude, and unit from current value to revealed answer
- Animation duration: 600ms (as specified in controller)
- Visual feedback shows the transition

**Actual Behavior**:
- Answer widget jumps instantly to revealed answer
- No animation visible
- Values change immediately without transition

**Reproduction Steps**:
1. Start a game and answer a question
2. Submit the answer
3. Wait for question to reveal
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
│   └── CarouselPageWrapper (keeps widgets alive when scrolled away)
│       └── Column (for each question)
│           └── GameCard (question + answer display)
│               ├── QuestionWidget (displays question text)
│               └── AnswerWidget (controlled component)
│                   ├── DigitWheels (number input with animation)
│                   ├── OmLabel (order of magnitude selector with animation)
│                   └── UnitTape (unit selector with animation)
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
AnswerController _answerController;        // Shared controller for current question
```

**Key Methods**:

**`getDisplayAnswer(int index)`** (lines 217-265):
Computes what value to display for a question with priority:
1. **Priority 1**: Animation progress (if actively animating) - `_animationProgress[index]`
2. **Priority 2**: Revealed answer (for revealed questions) - `getRevealedAnswer(index)`
3. **Priority 3**: User's current input (for current editable question)
4. **Priority 4**: Default fallback

**Critical Issue**: When `state.isRevealed == true` but animation hasn't started yet, this returns the revealed answer immediately (Priority 2), causing the widget to receive the final value before animation begins.

**`_triggerRevealAnimation(int index, AnswerValue correctAnswer)`** (lines 881-936):
Consolidated method that triggers reveal animation:
1. Sets `_animatingQuestionIndex = index`
2. Sets `_animationProgress[index] = startValue` (user's answer)
3. Uses post-frame callback to ensure widget is ready
4. Calls `_answerController.reveal()` with animation duration (600ms)
5. Updates `_animationProgress` during animation via `onProgress` callback
6. Clears animation state on completion

**Timing Issue**: Animation is triggered in a post-frame callback, but `getDisplayAnswer` may return revealed answer before animation starts, causing widget to sync controllers to final value.

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

**`didUpdateWidget()`** (lines 217-322):
Handles widget updates with priority system:
1. **Priority 1**: Handle revealed state (highest priority)
   - If controller is null: Apply immediately via `_jumpToRevealedValue()`
   - If controller is bound:
     - If animation pending/animating: Update color only, don't jump
     - If already revealed: Apply changes if props changed
     - **Otherwise**: Set `_isControllerAnimationPending = true` (line 311)
2. **Priority 2**: Reset if revealed props removed
3. **Priority 3**: Controller manages state when bound
4. **Priority 4**: Sync to value prop (prop-controlled mode)

**Critical Issue**: When revealed props arrive, widget sets `_isControllerAnimationPending = true`, but `widget.value` may already be the revealed answer (from `getDisplayAnswer`), causing controllers to sync to final value before animation starts.

**`_revealToValue()`** (lines 389-444):
Animation method called by controller:
1. Sets `_isControllerAnimating = true` and clears pending flag
2. Animates digits via `_digitsController.revealTo()`
3. Animates OM via `_omController.animateTo()`
4. Animates unit via `_unitController.animateTo()`
5. Updates state on completion

**`_syncControllersToValue()`** (lines 325-346):
Syncs sub-controllers to current value:
- If revealed: Syncs to `_revealedValue`
- Otherwise: Syncs to `widget.value`

**Critical Issue**: This method uses `jumpTo()` which instantly sets values, not `animateTo()`. If called with revealed value before animation starts, it prevents animation.

**`_jumpToRevealedValue()`** (lines 349-387):
Instantly jumps to revealed state without animation:
- Stores `_revealedValue`
- Sets `_hasBeenRevealed = true`
- Calls `jumpTo()` on all sub-controllers
- Sets color

#### 3. AnswerController
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

1. **Backend Event**: Game server sends reveal event
2. **Controller**: `_handleReveal()` or `_handlePlayersAnswers()` is called
   - Sets `QuestionState.isRevealed = true`
   - Sets `QuestionState.correctAnswer`
   - Calls `_triggerRevealAnimation(index, correctAnswer)`
3. **Controller State Update**: `notifyListeners()` triggers rebuild
4. **Screen Build**: `_buildGameCard()` for current question
   - Computes `displayAnswer = _controller.getDisplayAnswer(index)`
   - **Problem**: `getDisplayAnswer` returns revealed answer (Priority 2) because `isRevealed == true`
   - Passes `revealedAnswer` and `revealedColor` props
   - Binds `answerController` for current question
5. **Widget Rebuild**: `AnswerWidget.didUpdateWidget()` is called
   - Sees `hasRevealedProps == true` and `controller != null`
   - Sets `_isControllerAnimationPending = true` (line 311)
   - **Problem**: `widget.value` is already the revealed answer
6. **Controller Post-Frame**: `_triggerRevealAnimation` post-frame callback executes
   - Sets `_animatingQuestionIndex = index`
   - Sets `_animationProgress[index] = startValue`
   - Calls `_answerController.reveal()`
7. **Widget Animation**: `_revealToValue()` is called
   - **Problem**: Controllers may already be at target value (synced from `widget.value`)
   - Animation has nothing to animate, appears instant

**Expected Flow (Fixed)**:

1. **Backend Event**: Game server sends reveal event
2. **Controller**: `_handleReveal()` or `_handlePlayersAnswers()` is called
   - Sets `QuestionState.isRevealed = true`
   - Sets `QuestionState.correctAnswer`
   - Calls `_triggerRevealAnimation(index, correctAnswer)`
3. **Controller State Update**: `notifyListeners()` triggers rebuild
4. **Screen Build**: `_buildGameCard()` for current question
   - Computes `displayAnswer = _controller.getDisplayAnswer(index)`
   - **Fix**: `getDisplayAnswer` should return animation progress if animating, otherwise user answer (not revealed answer)
   - Passes `revealedAnswer` and `revealedColor` props
   - Binds `answerController` for current question
5. **Widget Rebuild**: `AnswerWidget.didUpdateWidget()` is called
   - Sees `hasRevealedProps == true` and `controller != null`
   - Sets `_isControllerAnimationPending = true`
   - **Fix**: `widget.value` should be user's answer (not revealed answer)
6. **Controller Post-Frame**: `_triggerRevealAnimation` post-frame callback executes
   - Sets `_animatingQuestionIndex = index`
   - Sets `_animationProgress[index] = startValue`
   - Calls `_answerController.reveal()`
7. **Widget Animation**: `_revealToValue()` is called
   - Controllers are at user's answer (starting point)
   - Animation smoothly transitions to revealed answer
   - `onProgress` updates `_animationProgress`, which updates `getDisplayAnswer`

### Root Cause Analysis

The root cause is a **timing/priority issue** in `getDisplayAnswer()`:

**Problem**: When a question is revealed, `getDisplayAnswer()` immediately returns the revealed answer (Priority 2) even if animation hasn't started yet. This causes:

1. Widget receives revealed answer as `value` prop before animation starts
2. Widget may sync controllers to revealed value (via `_syncControllersToValue()`)
3. When animation starts, controllers are already at target value
4. Animation has nothing to animate, appears instant

**The Fix**: `getDisplayAnswer()` should prioritize animation state **even before animation starts**. Specifically:

- If `_animatingQuestionIndex == index` (animation is scheduled/starting), return animation progress or user answer
- Only return revealed answer if animation is NOT in progress AND question is revealed

**Alternative Fix**: Ensure `getDisplayAnswer()` doesn't return revealed answer until animation completes. Use a flag or check animation state more carefully.

## ⚠️ CRITICAL WARNING: DO NOT SYNC CONTROLLERS IN Priority 1 PATH

**DO NOT** add `_syncControllersToValue()` calls in the Priority 1 path of `AnswerWidget.didUpdateWidget()` when revealed props arrive with controller bound (around lines 289-291).

**Why This Breaks Things**:
- When a user navigates away from a revealed question (hits "Next"), the leaving card rebuilds
- During navigation, `widget.value` may already be the revealed answer (from `getDisplayAnswer()` Priority 2)
- If you sync controllers to `widget.value` at this point, you reset the leaving card's controllers
- This breaks the **leaving card preservation** fix that was carefully implemented to prevent value/color resets

**What Happens**:
1. Question reveals, animation completes, `_hasBeenRevealed = true`
2. User presses "Next" to navigate away
3. Widget rebuilds with revealed props + controller still bound (during transition)
4. If sync happens here, controllers reset to `widget.value` (revealed answer)
5. Controller then unbinds, but controllers are now at wrong position
6. Leaving card shows incorrect state or resets

**The Fix Must**:
- Fix the animation issue WITHOUT touching `didUpdateWidget()` Priority 1 path for revealed props
- OR ensure any sync only happens when widget is guaranteed to be current question AND animation is about to start
- Preserve the existing leaving card preservation logic (lines 222-241 in `answer_widget.dart`)

**Previous Failed Attempt**:
- Added `_syncControllersToValue()` in Priority 1 path when revealed props arrive with controller bound
- Even with guards checking if `widget.value != revealedAnswer`, it still broke leaving cards
- The timing of when `widget.value` becomes the revealed answer vs when navigation happens is complex and fragile

**Correct Approach**:
- Fix must be in `getDisplayAnswer()` or `_triggerRevealAnimation()` timing
- Do NOT modify widget's `didUpdateWidget()` Priority 1 logic for revealed props
- The widget's current behavior (setting `_isControllerAnimationPending` and returning) is correct for preservation

## Attempted Fixes (All Failed)

### Attempt 0: Widget Controller Sync in Priority 1 Path (BROKE LEAVING CARDS - DO NOT REPEAT)

**Approach**: Added `_syncControllersToValue()` call in `AnswerWidget.didUpdateWidget()` Priority 1 path when revealed props arrive with controller bound.

**Changes Made**:
- Added sync call at lines 289-291 in `answer_widget.dart`
- Added guards to check if `widget.value != revealedAnswer` before syncing
- Attempted to ensure controllers are at user's answer before animation starts

**Result**:
- ❌ **BROKE LEAVING CARD PRESERVATION** - When navigating away, leaving cards reset their values
- Even with guards checking `widget.value != revealedAnswer`, timing issues caused resets
- The fix was immediately reverted

**Why It Failed**:
- During navigation transitions, `widget.value` may already be the revealed answer
- Syncing controllers at this point resets the leaving card's state
- The timing between when `widget.value` becomes revealed answer vs when controller unbinds is fragile
- This breaks the carefully implemented leaving card preservation logic

**Lesson Learned**:
- **DO NOT** modify `didUpdateWidget()` Priority 1 path for revealed props
- Fix must be in controller layer (`getDisplayAnswer()` or `_triggerRevealAnimation()` timing)
- Widget's current behavior (setting `_isControllerAnimationPending` and returning) is correct for preservation

### Attempt 1: Multi-Layer Defense Strategy

**Approach**: Implemented multiple layers of protection to prevent premature controller synchronization.

**Changes Made**:

1. **Layer 1 - Widget Priority 4 Guard** (`answer_widget.dart` line ~336):
   - Added `!_isControllerAnimationPending` check to Priority 4 condition
   - Prevents `_syncControllersToValue()` from running when animation is pending
   - **Result**: No change - animation still didn't play

2. **Layer 2 - Controller Priority 1 Enhancement** (`question_screen_v2_controller.dart` lines 222-238):
   - Enhanced Priority 1 in `getDisplayAnswer()` to return user answer when `_animatingQuestionIndex == index` but progress map is empty
   - Added fallback to return `state.userAnswer` when animation scheduled but not started
   - **Result**: No change - animation still didn't play

3. **Layer 3 - Widget Early Return** (`answer_widget.dart` lines 311-314):
   - Wrapped `_isControllerAnimationPending = true` assignment in `setState()`
   - Added explicit early return after setting pending flag
   - **Result**: No change - animation still didn't play

4. **Layer 4 - Immediate notifyListeners()** (`question_screen_v2_controller.dart` line 913):
   - Added `notifyListeners()` immediately after setting `_animatingQuestionIndex` and `_animationProgress` in `_triggerRevealAnimation()`
   - Ensures widget rebuilds with animation state set before post-frame callback
   - **Result**: No change - animation still didn't play

5. **Layer 5 - Explicit Controller Sync** (`answer_widget.dart` lines 314-322):
   - When revealed props arrive and animation pending, explicitly sync controllers to `widget.value` (user answer)
   - Used direct `jumpTo()` calls on sub-controllers to ensure they're at user answer before animation starts
   - **Result**: No change - animation still didn't play

**Why These Failed**:

Despite implementing all layers, the animation still doesn't play. Possible reasons:

1. **Controllers Already at Target**: Controllers might already be at the revealed answer value before `_revealToValue()` is called, making animation appear instant (no visual change)

2. **Timing Issue**: There may be a race condition where controllers get synced to revealed value AFTER we set the pending flag but BEFORE the post-frame callback runs

3. **Sub-Controller Behavior**: The sub-controllers (`DigitWheelsController`, `OmLabelController`, `UnitTapeController`) might have logic that skips animation if already at target value

4. **Multiple Rebuilds**: Multiple `notifyListeners()` calls might cause multiple rebuilds, and controllers might get synced in a later rebuild that we're not accounting for

5. **Widget Lifecycle**: The widget might be getting recreated or controllers might be getting reset somewhere we haven't identified

**Next Steps for Future Investigation**:

1. **Add Debug Logging**: Add extensive logging to track:
   - When `getDisplayAnswer()` is called and what it returns
   - When controllers are synced and to what values
   - When `_revealToValue()` is called and what the current controller values are
   - When sub-controller animation methods are called

2. **Check Sub-Controller Implementation** (HIGH PRIORITY): Investigate if `DigitWheelsController.revealTo()`, `OmLabelController.animateTo()`, and `UnitTapeController.animateTo()` skip animation when already at target. This is a **high priority** investigation - the sub-controllers might be checking current value vs target and skipping animation if they match. Check:
   - `apps/fermi-frontend/lib/widgets/digit_wheels.dart` - `_revealTo()` and `_animateTo()` methods (lines 293-311)
   - `apps/fermi-frontend/lib/widgets/om_label.dart` - `animateTo()` implementation
   - `apps/fermi-frontend/lib/widgets/unit_tape.dart` - `animateTo()` implementation
   - Look for early returns or conditional logic that checks `currentValue == targetValue`

3. **Trace Widget Lifecycle**: Check if widget is being recreated or if controllers are being reset during the reveal process

4. **Check for Other Sync Points**: Search for all places where controllers might be synced to revealed value (not just in `didUpdateWidget()`)

5. **Consider Alternative Architecture**: Maybe the issue is architectural - perhaps the animation should be triggered differently, or controllers should be managed differently during reveal

## Code References

### Key Files

1. **`apps/fermi-frontend/lib/screens/question_v2/question_screen_v2_controller.dart`**
   - Lines 217-265: `getDisplayAnswer()` method - **ROOT CAUSE**
   - Lines 881-936: `_triggerRevealAnimation()` method
   - Lines 906-930: Post-frame callback that calls `_answerController.reveal()`
   - Lines 853-933: `_handleReveal()` method
   - Lines 1128-1250: `_handlePlayersAnswers()` method

2. **`apps/fermi-frontend/lib/widgets/answer_widget.dart`**
   - Lines 217-322: `didUpdateWidget()` logic
   - Lines 289-312: Priority 1 handling (revealed state with controller bound)
   - Lines 325-346: `_syncControllersToValue()` method
   - Lines 349-387: `_jumpToRevealedValue()` method
   - Lines 389-444: `_revealToValue()` animation method

3. **`apps/fermi-frontend/lib/screens/question_v2/question_screen_v2.dart`**
   - Lines 385-491: `_buildGameCard()` method
   - Lines 394-395: `getDisplayAnswer()` call
   - Lines 397-401: Revealed props passing
   - Lines 457-460: Controller binding logic

### Related Files

- `apps/fermi-frontend/lib/widgets/digit_wheels.dart` - DigitWheelsController implementation
- `apps/fermi-frontend/lib/widgets/om_label.dart` - OmLabelController implementation
- `apps/fermi-frontend/lib/widgets/unit_tape.dart` - UnitTapeController implementation
- `apps/fermi-frontend/docs/BUG_REPORTS/answer_widget_revealed_state_preservation.md` - Previous bug report with architecture details

## Potential Solutions

### Solution 1: Fix `getDisplayAnswer()` Priority Logic

**Approach**: Modify `getDisplayAnswer()` to check if animation is scheduled/starting before returning revealed answer.

**Changes**:
```dart
AnswerValue getDisplayAnswer(int index) {
  final state = _questionStates[index];
  final bool isCurrentQuestion = index == _currentIndex;
  final bool showFeedback = state?.isRevealed ?? false;

  // Priority 1: Animation progress (if question is actively animating OR scheduled to animate)
  if (_animatingQuestionIndex == index) {
    if (_animationProgress.containsKey(index)) {
      return _animationProgress[index]!;
    }
    // Animation scheduled but not started yet - return user answer as starting point
    if (isCurrentQuestion && state != null) {
      return state.userAnswer ?? const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');
    }
  }

  // Priority 2: Revealed answer (ONLY if not animating)
  if (showFeedback && state != null && _animatingQuestionIndex != index) {
    final revealed = getRevealedAnswer(index);
    if (revealed != null) return revealed;
  }

  // ... rest of priorities
}
```

**Pros**:
- Fixes root cause directly
- Minimal changes
- Preserves existing architecture

**Cons**:
- Need to ensure `_animatingQuestionIndex` is set before `notifyListeners()`

### Solution 2: Delay Revealed Answer in `getDisplayAnswer()`

**Approach**: Don't return revealed answer until animation completes. Use a flag or check completion state.

**Changes**:
- Add `_revealAnimationComplete` map to track completed animations
- Only return revealed answer if animation completed or not animating

**Pros**:
- Ensures animation always has starting point
- Clear separation of concerns

**Cons**:
- More state to manage
- Need to track completion for all questions

### Solution 3: Prevent Controller Sync Before Animation

**Approach**: In `AnswerWidget.didUpdateWidget()`, don't sync controllers if animation is pending.

**Changes**:
```dart
// Priority 1: Handle revealed state
if (hasRevealedProps) {
  if (widget.controller == null) {
    // Prop-controlled: apply immediately
    _jumpToRevealedValue(widget.revealedAnswer!, widget.revealedColor!);
    return;
  }

  // Controller is bound
  if (_isControllerAnimationPending || _isControllerAnimating) {
    // Don't sync controllers - let animation handle it
    return;
  }

  // ... rest
}
```

**Pros**:
- Prevents premature syncing
- Simple change

**Cons**:
- Doesn't fix root cause (getDisplayAnswer still returns wrong value)
- May cause other issues

### Solution 4: Set Animation State Before State Update

**Approach**: Set `_animatingQuestionIndex` and `_animationProgress` BEFORE calling `notifyListeners()` in reveal handlers.

**Changes**:
```dart
void _triggerRevealAnimation(int index, AnswerValue correctAnswer) {
  // ... validation ...

  // Set animation state BEFORE notifyListeners
  _animatingQuestionIndex = index;
  _animationProgress[index] = startValue;

  // Trigger rebuild with animation state set
  notifyListeners();

  // Then schedule animation in post-frame callback
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // ... animation logic ...
  });
}
```

**Pros**:
- Ensures `getDisplayAnswer` returns correct value
- Minimal changes

**Cons**:
- Need to ensure animation actually starts (handle cancellation)

## Recommended Solution

**Solution 1 + Solution 4 Combined**:
1. Set animation state (`_animatingQuestionIndex` and `_animationProgress`) BEFORE `notifyListeners()`
2. Update `getDisplayAnswer()` to return user answer when animation is scheduled but not started
3. This ensures widget receives correct starting value and animation has something to animate

## Testing Strategy

### Manual Testing

1. **Basic Reveal Animation**:
   - Answer a question, submit, verify smooth animation to correct answer
   - Verify animation duration is ~600ms
   - Verify all components animate (digits, OM, unit)

2. **Final Question Animation**:
   - Complete game, verify final question animates correctly
   - Verify review mode activates after animation completes

3. **Navigation During Animation**:
   - Start reveal animation, navigate away before completion
   - Verify leaving card shows correct revealed state

### Unit Tests

Add tests to verify:
- `getDisplayAnswer()` returns user answer when animation is scheduled
- `getDisplayAnswer()` returns animation progress during animation
- `getDisplayAnswer()` returns revealed answer only after animation completes

## Success Criteria

1. ✅ Answer widget animates smoothly from user input to revealed answer
2. ✅ Animation duration is ~600ms as specified
3. ✅ All components animate (digits, OM, unit)
4. ✅ Final question animates correctly before review mode activates
5. ✅ No regressions in value/color preservation
6. ✅ No regressions in review mode behavior

## Related Documentation

- `apps/fermi-frontend/docs/BUG_REPORTS/answer_widget_revealed_state_preservation.md` - Previous bug report with detailed architecture
- `apps/fermi-frontend/docs/ARCHITECTURE.md` - Overall architecture documentation
- `apps/fermi-frontend/docs/TESTS.md` - Testing guidelines

## Environment

- **Framework**: Flutter 3.24.2
- **Platform**: Android (tested), iOS (likely affected)
- **Architecture**: MVVM with ChangeNotifier
- **State Management**: Provider pattern with ChangeNotifier

---

**Last Updated**: Current session (after multiple fix attempts, including failed widget sync approach)
**Status**: Open - Animation not playing, values jump instantly. Multiple fix attempts failed (see "Attempted Fixes" section above).
**Priority**: High - Core UX feature broken
**⚠️ WARNING**: See "CRITICAL WARNING" section above - DO NOT sync controllers in Priority 1 path as it breaks leaving card preservation
**Next Agent**: See "Next Steps for Future Investigation" in "Attempted Fixes" section for debugging approach. Fix must be in `getDisplayAnswer()` or `_triggerRevealAnimation()` timing, NOT in widget's `didUpdateWidget()`.
