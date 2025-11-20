## TEST_FEATURE_046 – `QuickAccessBar` widget tests

### Scope

Implement `QuickAccessBar` widget tests as described in `docs/TESTS.md` under:

- **Widget Tests → Widgets → `QuickAccessBar`**

Cover rendering, drag interaction, and progress updates.

### Code / Files Involved

- `lib/screens/question_v2/widgets/quick_access_bar.dart`
- Supporting widgets:
  - `lib/widgets/linear_determinate_progress_indicator.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Widget Tests → Widgets → `QuickAccessBar`”**
- `docs/TESTING_GUIDELINES.md`
  - Widget tests and gestures.

### Fixtures & Helpers

- Use `test/helpers/test_helpers.dart` to wrap the widget in a `MaterialApp` and `Scaffold`.

### Tasks for this Feature

1. Create `test/widget/widgets/quick_access_bar_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Rendering
   - Drag Interaction
3. Ensure:
   - Drag gestures beyond the threshold open/close the numpad/bottom sheets as expected.
   - Progress indicator updates during drag.

### Done Checklist

- [x] `quick_access_bar_test.dart` created with all required groups.
- [x] Drag gestures and resulting state changes are thoroughly tested.
- [x] `fvm flutter test test/widget/widgets/quick_access_bar_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Test file**: `test/widget/widgets/quick_access_bar_test.dart` - 10 tests total (3 rendering, 7 drag interaction)
- **Gesture testing approach**: Used `tester.startGesture()`, `gesture.moveBy()`, and `gesture.up()` to simulate vertical drag gestures
- **Thresholds tested**:
  - Upward drag threshold: 80px (triggers `onTrigger` callback)
  - Downward drag threshold: 20px (triggers `onClose` callback)
- **Timer handling**: The widget uses `Future.delayed(Duration(milliseconds: 200))` to reset drag distance after trigger. Tests use `pumpAndSettle(Duration(milliseconds: 250))` to wait for the timer to complete and avoid pending timer errors
- **Progress indicator**: The widget doesn't use a separate `LinearDeterminateProgressIndicator` widget. Instead, it uses color interpolation based on drag progress (text color interpolates from `bgLight` to `info` as drag distance increases)
- **Test coverage**: All rendering scenarios (enabled/disabled states) and drag interaction scenarios (upward drag above/below threshold, downward drag above/below threshold, progress updates, reset behavior, multiple gestures) are covered
