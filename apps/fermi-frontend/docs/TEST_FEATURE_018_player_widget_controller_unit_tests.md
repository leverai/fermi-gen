## TEST_FEATURE_018 – `PlayerWidgetController` unit tests

### Scope

Implement tests for `PlayerWidgetController` as described in `docs/TESTS.md` under:

- **Unit Tests → Widget Controllers → `PlayerWidgetController`**

Focus on binding, score updates, state persistence, and confetti triggering.

### Code / Files Involved

- `lib/widgets/player_widget_controller.dart`
- `lib/widgets/player_widget.dart` (for understanding how the controller is used)

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Widget Controllers → `PlayerWidgetController`”**
- `docs/TESTING_GUIDELINES.md`
  - Controller and widget testing guidance.

### Fixtures & Helpers

- Use data from `test/fixtures/player_data.dart` where helpful.

### Tasks for this Feature

1. Create `test/unit/widgets/player_widget_controller_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Binding
   - Score Updates
   - State Persistence
3. Validate that:
   - Confetti triggers correctly via controller calls.
   - Last round and cumulative scores are persisted and replayed as expected.

### Done Checklist

- [x] `player_widget_controller_test.dart` created with all described groups.
- [x] Tests are deterministic and free of real animations/UI.
- [x] `fvm flutter test test/unit/widgets/player_widget_controller_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- Tests were split into three files to keep each under 300 lines:
  - `test/unit/widgets/player_widget_controller/binding_test.dart` (149 lines)
  - `test/unit/widgets/player_widget_controller/score_updates_test.dart` (139 lines)
  - `test/unit/widgets/player_widget_controller/state_persistence_test.dart` (140 lines)
- All test groups from TESTS.md were implemented:
  - Binding: Tests callback binding and score replay on bind
  - Score Updates: Tests setRoundScore, setScore, triggerConfetti, clearConfetti
  - State Persistence: Tests score memory and disposal behavior
- All 17 tests pass successfully.
- The controller is a simple state holder with no external dependencies, making it straightforward to test in isolation.
