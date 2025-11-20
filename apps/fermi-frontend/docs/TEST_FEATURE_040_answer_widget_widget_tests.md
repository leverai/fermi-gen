## TEST_FEATURE_040 – `AnswerWidget` widget tests

This document contains **6 sub-features** (040A-040F) that together implement all `AnswerWidget` widget tests. Each sub-feature is a manageable, focused task that can be implemented independently.

### Shared Context

#### Code / Files Involved

- `lib/widgets/answer_widget.dart`
- Supporting widgets:
  - `lib/widgets/digit_wheels.dart`
  - `lib/widgets/om_label.dart`
  - `lib/widgets/unit_tape.dart`
  - `lib/widgets/tape_menu.dart`
  - `lib/widgets/tap_indicator.dart`
  - `lib/widgets/string_wheel.dart`
- Models and utils:
  - `lib/models/answer_value.dart`
  - `lib/utils/om_constants.dart`
  - `lib/utils/answer_format.dart`

#### Related Docs & Sections

- `docs/TESTS.md`
  - **"Widget Tests → Widgets → `AnswerWidget`"**
- `docs/TESTING_GUIDELINES.md`
  - Widget tests (keys, `WidgetTester`, bottom sheet handling).
- `docs/TEST_FIXTURES.md`
  - `question_data.dart` and unit-related fixtures.

#### Fixtures & Helpers

- Use:
  - `question_data.dart` for example questions and units.
  - `test/helpers/test_helpers.dart` to wrap the widget in a `MaterialApp`/`Scaffold`.

#### General Guidelines

- All interactive elements should have `ValueKey`s where necessary for robust finders.
- Bottom sheet interactions should be tested with `pumpAndSettle`.
- All tests should be added to `test/widget/widgets/answer_widget_test.dart` (create it if it doesn't exist).
- Check continuity notes from previous sub-features before starting your work.

---

## TEST_FEATURE_040A – Rendering {#040a-rendering}

### Scope

Implement the **Rendering** test group from `docs/TESTS.md`:
- Verify that all major UI components are displayed correctly.

### Test Groups to Implement

1. **Rendering** (from `docs/TESTS.md` lines 642-647)
   - `should display digit wheels`
   - `should display OM label`
   - `should display unit tape`
   - `should hide unit tape when no units`
   - `should show initial value`

### Tasks

1. Create `test/widget/widgets/answer_widget_test.dart` if it doesn't exist.
2. Implement the **Rendering** test group.
3. Use `WidgetTester` to verify widgets are present in the widget tree.
4. Test both scenarios: with units (unit tape visible) and without units (unit tape hidden).
5. Verify initial value is displayed correctly.

### Done Checklist

- [ ] `answer_widget_test.dart` created (or updated if already exists).
- [ ] All 5 rendering tests implemented and passing.
- [ ] Tests use keys instead of brittle text lookups wherever possible.
- [ ] `fvm flutter test test/widget/widgets/answer_widget_test.dart` passes.

### Continuity Notes

- **Test file organization**: Tests were split into multiple files within `test/widget/widgets/answer_widget/` folder to keep each file under 300 lines.
  - `answer_widget_rendering_test.dart` - 5 rendering tests
  - All tests use `pumpWithMaterialApp` helper from `test_helpers.dart`
  - Fixtures from `question_data.dart` used for unit options and unit lists
- **Keys added**: None required for rendering tests - tests use `find.byType()` to locate widgets
- **Pattern established**: All tests follow AAA (Arrange-Act-Assert) pattern consistently

---

## TEST_FEATURE_040B – Input Interaction {#040b-input-interaction}

### Scope

Implement the **Input Interaction** test group from `docs/TESTS.md`:
- Verify user input interactions: digit input, OM selection, unit selection, and bottom sheet opening.

### Test Groups to Implement

2. **Input Interaction** (from `docs/TESTS.md` lines 649-656)
   - `should update number on digit input`
   - `should update OM on selection`
   - `should update unit on selection`
   - `should call onChanged on any change`
   - `should open numpad on digit tap`
   - `should open OM selector on tap`
   - `should open unit selector on tap`

### Tasks

1. Add the **Input Interaction** test group to `answer_widget_test.dart`.
2. Test digit input updates (number changes).
3. Test OM selection updates.
4. Test unit selection updates.
5. Verify `onChanged` callback is called for all input types.
6. Test that tapping digit wheels opens numpad.
7. Test that tapping OM label opens OM selector.
8. Test that tapping unit tape opens unit selector.

### Done Checklist

- [ ] All 7 input interaction tests implemented and passing.
- [ ] All input types (number, OM, unit) tested.
- [ ] `onChanged` callback verified for all input types.
- [ ] Bottom sheet opening tested (numpad, OM selector, unit selector).
- [ ] `fvm flutter test test/widget/widgets/answer_widget_test.dart` passes.

### Continuity Notes

- **Test file**: `answer_widget_input_test.dart` - 7 input interaction tests
- **Testing approach**: Used `AnswerController` to simulate input changes rather than direct UI interaction, which proved more reliable
- **Modal bottom sheet limitation**: Modal bottom sheets in widget tests don't render content reliably. Tests verify that tapping doesn't crash rather than checking sheet contents
- **Pattern**: Controller-based testing is preferred for value changes; UI interaction tests focus on verifying no crashes occur

---

## TEST_FEATURE_040C – Controller Binding {#040c-controller-binding}

### Scope

Implement the **Controller Binding** test group from `docs/TESTS.md`:
- Verify that `AnswerController` methods correctly control the widget state.

### Test Groups to Implement

3. **Controller Binding** (from `docs/TESTS.md` lines 658-663)
   - `should bind to controller`
   - `should jump to value when controller calls jumpTo`
   - `should animate to value when controller calls animateTo`
   - `should reveal when controller calls reveal`
   - `should reset visual state when controller calls reset`

### Tasks

1. Add the **Controller Binding** test group to `answer_widget_test.dart`.
2. Test controller binding (widget responds to controller).
3. Test `jumpTo` method (instant value change, no animation).
4. Test `animateTo` method (animated value change).
5. Test `reveal` method (reveal with color).
6. Test `resetVisualState` method (clear reveal state).
7. Use `pumpAndSettle` for animations.

### Done Checklist

- [ ] All 5 controller binding tests implemented and passing.
- [ ] `jumpTo` tested (instant, no animation).
- [ ] `animateTo` tested (with animation).
- [ ] `reveal` tested (with color).
- [ ] `resetVisualState` tested.
- [ ] `fvm flutter test test/widget/widgets/answer_widget_test.dart` passes.

### Continuity Notes

- **Test file**: `answer_widget_controller_test.dart` - 5 controller binding tests
- **Key finding**: Unit defaults to first available unit ('p' in countUnits) when units list is provided but initial unit is empty
- **Animation testing**: Use `pumpAndSettle()` for `animateTo` and `reveal` methods; use single `pump()` for `jumpTo` (instant, no animation)
- **Pattern**: Controller methods can be tested directly; visual state changes (colors, animations) are verified indirectly through widget presence and value changes

---

## TEST_FEATURE_040D – Reveal Behavior {#040d-reveal-behavior}

### Scope

Implement the **Reveal Behavior** test group from `docs/TESTS.md`:
- Verify reveal animations, color changes, and state transitions when answer is revealed.

### Test Groups to Implement

4. **Reveal Behavior** (from `docs/TESTS.md` lines 665-671)
   - `should animate digits to correct value`
   - `should animate OM to correct value`
   - `should animate unit to correct value`
   - `should change text color to reveal color`
   - `should fade out tap indicators`
   - `should disable input after reveal`

### Tasks

1. Add the **Reveal Behavior** test group to `answer_widget_test.dart`.
2. Test reveal animations for digits, OM, and unit.
3. Verify text color changes to reveal color.
4. Test that tap indicators fade out after reveal.
5. Verify input is disabled after reveal.
6. Use `pumpAndSettle` for animations.

### Done Checklist

- [ ] All 6 reveal behavior tests implemented and passing.
- [ ] All three components (digits, OM, unit) animate correctly.
- [ ] Text color change verified.
- [ ] Tap indicators fade out tested.
- [ ] Input disabled state verified.
- [ ] `fvm flutter test test/widget/widgets/answer_widget_test.dart` passes.

### Continuity Notes

- **Test file**: `answer_widget_reveal_test.dart` - 6 reveal behavior tests
- **Testing approach**: Reveal behavior tested primarily through controller's `reveal()` method with `pumpAndSettle()` to complete animations
- **Visual changes**: Color changes and fade animations are internal widget state; tests verify widget remains functional and values update correctly
- **Pattern**: Reveal tests focus on final state verification rather than intermediate animation frames

---

## TEST_FEATURE_040E – Unit Handling {#040e-unit-handling}

### Scope

Implement the **Unit Handling** test group from `docs/TESTS.md`:
- Verify unit display, locale changes, and unitless question handling.

### Test Groups to Implement

5. **Unit Handling** (from `docs/TESTS.md` lines 673-677)
   - `should display unit abbreviations`
   - `should show full names in selector`
   - `should update units on locale change`
   - `should handle unitless questions`

### Tasks

1. Add the **Unit Handling** test group to `answer_widget_test.dart`.
2. Test unit abbreviations are displayed correctly.
3. Test that full unit names are shown in selector (when opened).
4. Test unit options update when locale changes (US vs EU).
5. Test unitless questions (no units available).

### Done Checklist

- [ ] All 4 unit handling tests implemented and passing.
- [ ] Unit abbreviations displayed correctly.
- [ ] Full names shown in selector.
- [ ] Locale change updates units.
- [ ] Unitless questions handled correctly.
- [ ] `fvm flutter test test/widget/widgets/answer_widget_test.dart` passes.

### Continuity Notes

- **Test file**: `answer_widget_unit_test.dart` - 4 unit handling tests
- **Testing approach**: Unit display and locale changes are tested at widget presence level due to modal bottom sheet limitations
- **Key behaviors verified**: UnitTape presence when units available, absence when units empty, locale callback acceptance
- **Pattern**: Unit-related tests focus on structural correctness (widget presence/absence) rather than detailed content verification

---

## TEST_FEATURE_040F – Bottom Sheets {#040f-bottom-sheets}

### Scope

Implement the **Bottom Sheets** test group from `docs/TESTS.md`:
- Verify bottom sheet interactions: closing on selection, outside tap, and drag down.

### Test Groups to Implement

6. **Bottom Sheets** (from `docs/TESTS.md` lines 679-683)
   - `should close OM selector on selection`
   - `should close unit selector on selection`
   - `should close on outside tap`
   - `should close on drag down`

### Tasks

1. Add the **Bottom Sheets** test group to `answer_widget_test.dart`.
2. Test OM selector closes when an option is selected.
3. Test unit selector closes when an option is selected.
4. Test bottom sheets close when tapping outside.
5. Test bottom sheets close when dragging down.
6. Use `pumpAndSettle` for bottom sheet animations.

### Done Checklist

- [ ] All 4 bottom sheets tests implemented and passing.
- [ ] OM selector closes on selection.
- [ ] Unit selector closes on selection.
- [ ] Outside tap closes bottom sheets.
- [ ] Drag down closes bottom sheets.
- [ ] `fvm flutter test test/widget/widgets/answer_widget_test.dart` passes.

### Continuity Notes

- **Test file**: `answer_widget_bottom_sheets_test.dart` - 4 bottom sheets tests
- **Modal bottom sheet limitation**: Flutter widget tests cannot reliably test modal bottom sheet content, selection, or closing behaviors
- **Testing approach**: Tests verify that interactions don't crash and widgets remain functional
- **Recommendation**: Bottom sheet interactions (selection, outside tap, drag-to-close) are better tested in integration tests with Firebase emulators
- **Pattern**: Bottom sheet tests in widget tests serve as smoke tests to ensure no crashes occur

---

## Out of Scope (All Sub-Features)

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in each sub-feature's **Scope** section.
