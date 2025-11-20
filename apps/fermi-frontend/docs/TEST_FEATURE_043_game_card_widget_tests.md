## TEST_FEATURE_043 – `GameCard` widget tests

### Scope

Implement `GameCard` widget tests as described in `docs/TESTS.md` under:

- **Widget Tests → Widgets → `GameCard`**

Cover rendering, state management (editable vs revealed), feedback row, height animation, and percentile display.

### Code / Files Involved

- `lib/screens/question_v2/widgets/game_card.dart`
- Related widgets:
  - `lib/widgets/question_widget.dart`
  - `lib/widgets/answer_widget.dart`
  - `lib/widgets/submitted_answer_chip.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Widget Tests → Widgets → `GameCard`”**
- `docs/TESTING_GUIDELINES.md`
  - Widget tests, animations (`pumpAndSettle`).
- `docs/TEST_FIXTURES.md`
  - `question_data.dart` and scoring/percentile fixtures.

### Fixtures & Helpers

- Use:
  - Question and answer fixtures from `question_data.dart`.
  - Player/score fixtures as needed to compute percentiles.

### Tasks for this Feature

1. Create `test/widget/widgets/game_card_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Rendering
   - State Management
3. Ensure:
   - The feedback row appears only after reveal and animates height.
   - Percentile text is visible when ≥ 50% and hidden otherwise.

### Done Checklist

- [x] `game_card_test.dart` created with all required groups.
- [x] Height animations and state transitions are tested with appropriate `pump`/`pumpAndSettle` usage.
- [x] `fvm flutter test test/widget/widgets/game_card_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

**Completed**: All GameCard widget tests implemented and passing (14 tests total).

**Test Groups Implemented**:
1. **Rendering** (7 tests): Verified display of question widget, answer widget, answer mirror text, feedback row visibility/animations, and divider.
2. **State Management** (7 tests): Verified editable/revealed states, answer passing, color propagation, and copy functionality.

**Key Implementation Details**:
- Feedback row visibility is controlled by `AnimatedOpacity` with 300ms duration, tested using `pumpAndSettle()`.
- Copy functionality is enabled only when `showFeedback` is true OR `reviewMode` is true, tested using `pumpWithScaffold()` to capture snackbar messages.
- Revealed color is passed to both `QuestionWidget` and `AnswerWidget` for consistent coloring.
- `AnswerMirrorText` correctly displays submitted answer during reveal when both `submittedAnswer` is provided and `editable` is false.

**Note on Percentile Tests**:
The original test specification mentioned testing "should show percentile when >= 50%" and "should hide percentile when < 50%". However, after inspecting the codebase, the percentile display is NOT part of the `GameCard` widget itself. The `SimplePercentileText` widget is rendered by the parent `QuestionScreenV2` widget in a separate `SizedBox` above the `GameCard` (see `question_screen_v2.dart` lines 441-452). The percentile logic (showing when >= 0.5) is also implemented in `QuestionScreenV2` (line 434). Therefore, percentile tests are properly covered by the `QuestionScreenV2` widget tests (TEST_FEATURE_032A-F), not `GameCard` tests.

**Fixtures Used**:
- `QuestionDataFixtures.sampleQuestion1` for question text
- `QuestionDataFixtures.geographyTags` for tags
- `QuestionDataFixtures.usUnitOptions` for unit options
- `QuestionDataFixtures.countUnits` for unit lists

**No upstream issues found** - all tests passed on first run.
