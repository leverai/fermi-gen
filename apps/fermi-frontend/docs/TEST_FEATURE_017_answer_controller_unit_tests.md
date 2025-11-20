## TEST_FEATURE_017 – `AnswerController` unit tests

### Scope

Implement tests for `AnswerController` as described in `docs/TESTS.md` under:

- **Unit Tests → Widget Controllers → `AnswerController`**

Focus on the controller’s behavior, not the full `AnswerWidget` UI.

### Code / Files Involved

- `lib/widgets/answer_widget.dart` (controller definition/binding)
- Any dedicated controller class file if it exists (e.g., `AnswerController` type alias or class).

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Widget Controllers → `AnswerController`”**
- `docs/TESTING_GUIDELINES.md`
  - Guidance on testing controllers and widget-related logic.

### Fixtures & Helpers

- Use basic `AnswerValue` instances (you may reuse helpers from `TEST_FEATURE_016` if created).
- No Firebase or network dependencies should be involved.

### Tasks for this Feature

1. Create `test/unit/widgets/answer_controller_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Binding
   - Value Operations
   - Default Values
3. Verify:
   - Controller binding lifecycle works as expected.
   - `jumpTo`, `animateTo`, `reveal`, `reset`, and focus-related behaviors call the right callbacks.
   - Controller behaves gracefully when not bound.

### Done Checklist

- [x] `answer_controller_test.dart` created with all described groups.
- [x] Tests focus on controller logic and do not require full widget trees or animations.
- [x] `fvm flutter test test/unit/widgets/answer_controller_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Test Helper Created**: Created `createBoundController` helper function in the test file to handle binding the controller through a minimal widget setup. This is necessary because `_bind` is private and can only be accessed through the widget's `initState`.

- **Testing Approach**: Used `testWidgets` for tests that require binding (Binding and Value Operations groups) to trigger the widget's `initState` which binds the controller. Used regular `test` for Default Values group since those tests verify behavior when the controller is not bound.

- **Controller-Widget Coupling**: The controller is tightly coupled to the widget's binding mechanism. The `_bind` method is private, so unit tests must use a minimal widget setup to trigger binding. This is acceptable for unit tests as we're still testing the controller's logic, not the widget's rendering.

- **Test File Size**: Test file is 224 lines, well under the 300 line limit.

- **All Tests Pass**: All 12 tests pass successfully, covering:
  - Binding: 4 tests (bind sub-controllers, expose current value getter, expose reveal function, expose reset function)
  - Value Operations: 6 tests (jumpTo, animateTo, reveal, resetVisualState, closeBottomSheets, requestFocus)
  - Default Values: 2 tests (default value when not bound, graceful handling when not bound)
