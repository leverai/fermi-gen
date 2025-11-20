## TEST_FEATURE_045 – `SubmitBar` widget tests

### Scope

Implement `SubmitBar` widget tests as described in `docs/TESTS.md` under:

- **Widget Tests → Widgets → `SubmitBar`**

Cover rendering, progress indicators, and action callbacks.

### Code / Files Involved

- `lib/screens/question_v2/widgets/submit_bar.dart`
- Supporting widgets:
  - `lib/widgets/linear_determinate_progress_indicator.dart`
  - `lib/widgets/circular_determinate_spinner.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Widget Tests → Widgets → `SubmitBar`”**
- `docs/TESTING_GUIDELINES.md`
  - Widget tests and animation handling.

### Fixtures & Helpers

- Use controller / state mocks from `QuestionScreenV2Controller` tests (if shared) or create simple local state.

### Tasks for this Feature

1. Create `test/widget/widgets/submit_bar_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Rendering
   - Progress Indicators
   - Actions
3. Ensure:
   - Text and enabled/disabled state change with props (editable, host, last question).
   - Progress indicators update over time (test using `pump`/`pumpAndSettle`).
   - `onSubmit`, `onNext`, `onFinish` callbacks are called exactly once per tap as appropriate.

### Done Checklist

- [x] `submit_bar_test.dart` created with all required groups.
- [x] Tests verify text, state, progress visuals, and callbacks.
- [x] `fvm flutter test test/widget/widgets/submit_bar_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

**Completed**: All SubmitBar widget tests implemented and passing (17 tests total).

**Test Groups Implemented**:
1. **Rendering** (5 tests): Verified submit/next/finish button labels based on state, disabled state for non-host, loading state when locked.
2. **Progress Indicators** (7 tests): Verified auto-next progress display conditions (shown only when state is finished and progress is between 0-1), progress updates over time, different behaviors for host/non-host on last question.
3. **Actions** (5 tests): Verified onSubmit/onNext/onFinish callbacks are called correctly, disabled button doesn't trigger actions, locked state doesn't trigger actions.

**Key Implementation Details**:
- **State-based rendering**: SubmitBar renders different button states based on `QuestionPaneState` enum (started/locked/finished), `isLast` flag, and `isHost` flag.
- **Button labels**:
  - `started` → "Submit"
  - `finished + !isLast + isHost` → "Next"
  - `finished + isLast + isHost` → "Finish"
- **Loading animations**: Tests with `isLoading: true` use `pump()` instead of `pumpAndSettle()` to avoid timeout since loading animations never settle.
- **Progress indicator**: `CircularDeterminateSpinner` is shown in top-right corner of button when `autoNextProgress` is between 0 and 1, and state is `finished`. For last question, only shown when user is host.

**Important Testing Pattern**:
When testing widgets with infinite animations (like loading spinners), use `tester.pump()` instead of `tester.pumpAndSettle()` to avoid timeout errors. This was applied to the "locked" state tests.

**No upstream issues found** - all tests passed after fixing animation timeout issue.
